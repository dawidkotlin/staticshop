import tables, httpcore, strutils, parseutils, asyncnet, asyncdispatch, strtabs, strformat, strutils, std/[exitprocs, wrapnils], os, cookies, marshal, db_sqlite, oids, database

type
  ReqVars* = object
    session*: tuple[notif, notifKind: string]
    code*: HttpCode
    params: StringTableRef
    respHeaders, respBody*, reqUserRowid*, reqUserFirstname*, reqUserLastname*, reqUserEmail*: string
  NodeCb = proc(reqVars: var ReqVars) {.nimcall.}
  Node = ref object
    cb: NodeCb
    kids: Table[string, Node]

var
  roots: array[HttpMethod, Node]

proc addRoute*(meth: HttpMethod, path: string, cb: NodeCb) =
  if roots[meth] == nil: roots[meth] = Node()
  var node = roots[meth]
  if path != "/":
    for it in path.substr(1).split('/'): node = node.kids.mgetOrPut(it, Node())
  assert node.cb == nil
  node.cb = cb

proc addHeader*(vars: var ReqVars, key, val: string) =
  vars.respHeaders.add &"{key}: {val}\n"

proc redirect*(vars: var ReqVars, path: string) =
  vars.addHeader "Location", path
  vars.code = Http303

proc param*(vars: var ReqVars, key: string): string =
  result = vars.params.getOrDefault(key)

proc serve(client: AsyncSocket) {.async.} =
  proc parseQuery(s: string, start: int): StringTableRef =
    result = newStringTable(modeCaseInsensitive)
    var i = 0
    while i <= s.high:
      var key: string
      inc i, s.parseUntil(key, {'=', '&'}, i)
      if key == "": break
      if s[i] == '&':
        inc i
        result[key] = key
      else:
        inc i
        var val: string
        inc i, s.parseUntil(key, '&', i) + 1
        result[key] = val
  const extToMime = toTable {".png": "image/png"}
  const sessionKeyCookie = "staticshopSessionKey"
  block mainLoop:
    while true:
      var sessionKey: string
      var vars = ReqVars(params: newStringTable(modeCaseInsensitive))
      var reqHeaders: Table[string, seq[string]]
      block outer:
        let req = await client.recvLine() ## isClosed is lagging behind recvLine returning ""! *PROPABLY WRONG ABOUT THIS*
        if req == "": break mainLoop ## this is why I have to assume that req == "" means client is closed *PROPABLY WRONG ABOUT THIS*
        var meth: HttpMethod
        var path: string
        block parseFirstRow:
          var i = 0
          meth =
            case (var s: string; i += req.parseUntil(s, Whitespace, i) + 1; s)
            of "GET": HttpGet
            of "POST": HttpPost
            else: vars.code = Http400; break outer
          if (let it = req[i]; it in {'\'', '"'}):
            inc i, req.parseUntil(path, it, i) + 2
          else:
            inc i, req.parseUntil(path, Whitespace, i) + 1
          if meth == HttpGet:
            let i = path.rfind('?')
            if i >= 0: vars.params = parseQuery(path, i+1)
          if not req.substr(i).startsWith("HTTP/1.1"): vars.code = Http400; break
        block:
          # parse headers
          var i = 0
          while true:
            let row = await client.recvLine()
            if row == "\c\L": break
            var key: string
            i += req.parseUntil(key, ':', i) + 2 # skip ": "
            if key == "": vars.code = Http400; break outer
            key = key.toLowerAscii()
            while true:
              var val: string
              i += req.parseUntil(val, ',', i) + 1
              if val == "": vars.code = Http400; break outer
              reqHeaders.mgetOrPut(key, @[]).add val
              if i > req.high: break
          if meth == HttpPost:
            ## parse body
            if "content-length" notin reqHeaders: vars.code = Http411; break outer
            let expectedLen = try: reqHeaders["content-length"][0].parseInt() except ValueError: (vars.code = Http411; break)
            let body = if expectedLen > 0: await client.recv(expectedLen) else: "" 
            if body.len != expectedLen: vars.code = Http411; break outer
            if "content-type" notin reqHeaders: vars.code = Http400; break outer
            if reqHeaders["content-type"][0] == "multipart/form": vars.code = Http404; break outer
            vars.params = parseQuery(body, 0)
            ## try to get the database
            if "Cookie" in reqHeaders:
              let cookies = reqHeaders["Cookie"][0].parseCookies()
              if cookies != nil and sessionKeyCookie in cookies:
                sessionKey = cookies[sessionKeyCookie]
                let sessionRow = row[tuple[data, user: string]](sql"select rowid, data, user from sessions where key = ?", sessionKey)
                vars.reqUserRowid = sessionRow.user
                let user = row[tuple[firstName, lastName, email: string]](sql"select firstName, lastName, email from users where rowid = ?", vars.reqUserRowid)
                vars.reqUserFirstName = user.firstName
                vars.reqUserLastName = user.lastName
                vars.reqUserEmail = user.email
                vars.session = to[vars.session.typeof] sessionRow.data
        vars.code = Http404
        ## find route
        block findRoute:
          if roots[meth] != nil:
            var node = roots[meth]
            var pathi = path.find('/') + 1
            var token: string
            let pathEnd = if (let i = path.rfind('?'); i >= 0): i else: path.high
            while pathi < pathEnd:
              pathi += path.parseUntil(token, '/', pathi) + 1
              if token notin node.kids: break findRoute
              node = node.kids[token]
            if ?.node.cb != nil:
              vars.code = Http200
              node.cb(vars)
              vars.addHeader "Content-Length", $((vars.respBody.len + 7) div 8)
              vars.addHeader "Content-Type", "text/html"
              break outer
        ## find file
        path = "public" / path
        if fileExists(path) and (let split = expandFilename(path).splitFile(); split.dir == getAppDir() / "public" and split.ext in extToMime):
          vars.code = Http200
          vars.respBody = readFile path
          vars.addHeader "Content-Type", extToMime[split.ext]
      assert vars.code != HttpCode(0)
      if sessionKey == "": sessionKey = $genOid()
      db.exec sql"replace into session(key, data) values (?, ?)", sessionKey, $$vars.session
      if client.isClosed or "Connection" in reqHeaders and reqHeaders["Connection"][0].toLowerAscii() != "keep-alive": break mainLoop
      let resp = &"HTTP/1.1 " & toUpperAscii($vars.code) & "\n" & vars.respHeaders & "\r\n" & vars.respBody
      echo "vars.code = ", vars.code
      await client.send resp
  client.close()

proc serve* {.async.} =
  let server = newAsyncSocket()
  server.setSockOpt OptReuseAddr, true
  server.bindAddr Port(8080)
  server.listen()
  addExitProc proc = server.close()
  while true:
    asyncCheck serve await server.accept()