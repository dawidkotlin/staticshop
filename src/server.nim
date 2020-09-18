import tables, httpcore, strutils, parseutils, asyncnet, asyncdispatch, strformat, strutils, os, oids, database, db_sqlite, uri

type
  ReqVars* = object
    session*: tuple[notification, notificationKind, langId, prevGetRoutePath: string]
    respCode*: HttpCode
    reqHeaders*, params: Table[string, seq[string]]
    respHeaders*, respBody*, userId*, userEmail*, sessionId*, pathWithQuery*, pathWithoutQuery*: string
    httpMethod*: HttpMethod

  NodeCb = proc(reqVars: var ReqVars) {.nimcall.}
  
  Node = ref object
    cb: NodeCb
    kids: Table[string, Node]

var
  roots: array[HttpMethod, Node]

proc addRoute*(httpMethod: HttpMethod, path: string, cb: NodeCb) =
  if roots[httpMethod] == nil: roots[httpMethod] = Node()
  var node = roots[httpMethod]
  if path != "/":
    for it in path.substr(1).split('/'):
      node = node.kids.mgetOrPut(it, Node())
  assert node.cb == nil
  node.cb = cb

proc addHeader*(vars: var ReqVars, key, val: string) =
  vars.respHeaders.add &"{key}: {val}\n"

proc hasParam*(vars: var ReqVars, key: string): bool =
  let key = key.toLowerAscii()
  result = key in vars.params

proc param*(vars: var ReqVars, key: string): string =
  let key = key.toLowerAscii()
  if key in vars.params:
    result = vars.params[key][0].decodeUrl()

iterator params*(vars: var ReqVars, key: string): string =
  let key = key.toLowerAscii()
  if key in vars.params:
    for it in vars.params[key]:
      yield it.decodeUrl()

iterator params*(vars: var ReqVars): tuple[key, val: string] =
  for key in vars.params.keys:
    for val in vars.params[key]:
      yield (key, val)

proc parseQuery(s: string, start: int): Table[string, seq[string]] =
  var i = start
  while i <= s.high:
    var key: string
    inc i, s.parseUntil(key, {'=', '&'}, i)
    if key == "": break
    key = key.toLowerAscii()
    if s[i] == '&':
      inc i
      result.mgetOrPut(key, @[]).add key
    else:
      inc i
      var val: string
      inc i, s.parseUntil(val, '&', i) + 1
      result.mgetOrPut(key, @[]).add val

proc serve(client: AsyncSocket) {.async.} =
  const
    extToMime = toTable {".png": "image/png"}
    sessionKeyCookie = "staticshopSessionKey"
  block mainLoop:
    while true:
      var vars = ReqVars(respCode: HttpCode(0))
      block outer:
        let firstRow = await client.recvLine()
        if firstRow == "": break mainLoop
        var rowi = 0
        var methodStr: string
        rowi += firstRow.parseUntil(methodStr, Whitespace, rowi) + 1
        case methodStr
        of "GET": vars.httpMethod = HttpGet
        of "POST": vars.httpMethod = HttpPost
        else:
          vars.respCode = Http400
          break outer
        
        if (let ch = firstRow[rowi]; ch in {'\'', '"'}):
          inc rowi, firstRow.parseUntil(vars.pathWithQuery, ch, rowi) + 2
        else:
          inc rowi, firstRow.parseUntil(vars.pathWithQuery, Whitespace, rowi) + 1

        if (let i = vars.pathWithQuery.rfind('?'); i >= 0):
          vars.params = parseQuery(vars.pathWithQuery, i+1)
          vars.pathWithoutQuery = vars.pathWithQuery.substr(0, i-1)
        else:
          vars.pathWithoutQuery = vars.pathWithQuery
        
        # echo (vars.httpMethod, vars.pathWithQuery)

        if not firstRow.substr(rowi).startsWith("HTTP/1.1"):
          vars.respCode = Http400
          break outer
        
        while true:
          let headerRow = await client.recvLine()
          if headerRow == "": break mainLoop
          if headerRow == "\c\L": break
          var key: string
          var i = 0
          i += headerRow.parseUntil(key, ':', i) + 2 # skip ": "
          if key == "":
            vars.respCode = Http400
            break outer
          key = key.toLowerAscii()
          while i <= headerRow.high:
            var val: string
            i += headerRow.parseUntil(val, ',', i) + 1
            if val == "":
              vars.respCode = Http400
              break outer
            vars.reqHeaders.mgetOrPut(key, @[]).add val
        
        if vars.httpMethod == HttpPost and "content-length" notin vars.reqHeaders:
          vars.respCode = Http411
          break outer
        
        if "content-length" in vars.reqHeaders:
          let expectedBytes =
            try:
              vars.reqHeaders["content-length"][0].parseInt()
            except ValueError:
              vars.respCode = Http411
              break
          
          if expectedBytes > 0:
            let body = await client.recv(expectedBytes)
            if body == "":
              break mainLoop 
            if body.len != expectedBytes:
              vars.respCode = Http411
              break outer
            if "content-type" notin vars.reqHeaders:
              vars.respCode = Http400
              break outer
            if vars.reqHeaders["content-type"][0] == "multipart/form":
              vars.respCode = Http404
              break outer
            
            vars.params = parseQuery(body, 0)

        var
          cookies: Table[string, string]
  
        if "cookie" in vars.reqHeaders:
          for header in vars.reqHeaders["cookie"]:
            for pair in header.split("; "):
              let eq = pair.find('=')
              if eq >= 0:
                let key = pair.substr(0, eq-1)
                let val = pair.substr(eq+1)
                cookies[key] = val
        
        var sessionData, maybeUserId: string
        if sessionKeyCookie in cookies:
          let sessionKey = cookies[sessionKeyCookie]
          db.getRow(sql"select rowid, data, user from session where key = ?", sessionKey)
            .unpack vars.sessionId, sessionData, maybeUserId
        if vars.sessionId != "":
          var i = 0
          for it in vars.session.fields:
            inc i, sessionData.parseUntil(it, '\1', i) + 1
          if maybeUserId != "":
            let maybeUserEmail = db.getValue(sql"select email from user where rowid = ?", maybeUserId)
            if maybeUserEmail != "": ## This confirms that the user exists
              vars.userId = maybeUserId
              vars.userEmail = maybeUserEmail
        else:
          let key = $genOid()
          vars.addHeader "Set-Cookie", (sessionKeyCookie & "=" & key)
          vars.sessionId = $db.insertID(sql"insert into session(key, data) values (?, '')", key)
          vars.session.prevGetRoutePath = "/"
          vars.session.langId = "2" ## English?

        # if sessionKeyCookie in cookies:
        #   var packedSession, userId: string
        #   let row = db.getRow(sql"select rowid, data, user from session where key = ?", cookies[sessionKeyCookie])
        #   row.unpack vars.sessionId, packedSession, userId
        #   if vars.sessionId != "":
        #     var i = 0
        #     for it in vars.session.fields:
        #       inc i, packedSession.parseUntil(it, '\1', i) + 1
        #     if userId != "":
        #       let userEmail = db.getValue(sql"select email from user where rowid = ?", userId)
        #       if userEmail != "": ## This confirms that the user exists
        #         vars.userId = userId
        #         vars.userEmail = userEmail
        #   else:
        #     let key = $genOid()
        #     vars.addHeader "Set-Cookie", (sessionKeyCookie & "=" & key)
        #     vars.sessionId = $db.insertID(sql"insert into session(key, data) values (?, '')", key)
        #     vars.session.prevGetRoutePath = "/"
        #     vars.session.langId = "2" ## English?

        block tryCallRoute:
          if roots[vars.httpMethod] != nil:
            var node = roots[vars.httpMethod]
            var pathi = vars.pathWithoutQuery.find('/') + 1
            while pathi <= vars.pathWithoutQuery.high:
              var token: string
              pathi += vars.pathWithoutQuery.parseUntil(token, '/', pathi) + 1
              if token notin node.kids:
                # echo "---------------------------------"
                # echo vars.httpMethod
                # for it in node.kids.keys: echo it
                # echo ""
                break tryCallRoute
              node = node.kids[token]
            if node != nil and node.cb != nil:
              vars.respCode = Http200
              node.cb vars
              vars.addHeader "Content-Length", $vars.respBody.len
              vars.addHeader "Content-Type", "text/html"
              if vars.httpMethod == HttpGet:
                vars.session.notification = ""
                vars.session.notificationKind = ""
                vars.session.prevGetRoutePath = vars.pathWithQuery
              break outer
        
        if vars.httpMethod == HttpGet:
          let filepath = "public" / vars.pathWithoutQuery
          if fileExists(filepath):
            let file = expandFilename(filepath).splitFile()
            if file.dir == getAppDir() / "public" and file.ext in extToMime:
              vars.respCode = Http200
              vars.respBody = readFile filepath
              vars.addHeader "Content-Type", extToMime[file.ext]
              vars.addHeader "Content-Length", $(vars.respBody.len)
        
        vars.addHeader "Content-Type", "text/html"
        vars.respBody = $vars.respCode

      var sessionPacked: string
      for it in vars.session.fields:
        sessionPacked.add it & '\1'
      
      db.exec sql"update session set data = ? where rowid = ?", sessionPacked, vars.sessionId

      await client.send "HTTP/1.1 " & toUpperAscii($vars.respCode) & "\n" &
        vars.respHeaders & "\r\n" &
        vars.respBody

      if vars.httpMethod == HttpPost or client.isClosed or vars.respCode.int in 400..<500 or
          ("Connection" in vars.reqHeaders and
          cmpIgnoreCase(vars.reqHeaders["Connection"][^1], "keep-alive") != 0):
        client.close()
        break mainLoop

let
  server = newAsyncSocket() ## it's a global because addQuitProc with a closure causes a compile-time error 😢

proc serve* {.async.} =
  server.setSockOpt OptReuseAddr, true
  server.bindAddr Port(8080)
  server.listen()
  addQuitProc: server.close()
  while true:
    asyncCheck serve await server.accept()