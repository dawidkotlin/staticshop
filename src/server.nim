import tables, httpcore, strutils, parseutils, asyncnet, asyncdispatch, strtabs, strformat, strutils, std/[exitprocs, wrapnils], os, cookies, marshal, oids, database, db_sqlite, uri
import sugar, sequtils

type
  ReqVars* = object
    session*: tuple[notif, notifKind, langId, prevGet: string]
    code*: HttpCode
    params: Table[string, seq[string]]
    respHeaders, respBody*, userId*, userEmail*, sessionId*, pathWithQuery: string
  
  NodeCb = proc(reqVars: var ReqVars) {.nimcall.}
  
  Node = ref object
    cb: NodeCb
    kids: Table[string, Node]

var
  roots: array[HttpMethod, Node]

proc addRoute*(meth: HttpMethod, path: string, cb: NodeCb) =
  if roots[meth] == nil:
    roots[meth] = Node()
  
  var node = roots[meth]
  
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
    
    if key == "":
      break
    
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
  const extToMime = toTable {".png": "image/png"}
  const sessionKeyCookie = "staticshopSessionKey"
  
  block mainLoop:
    while true:
      var meth: HttpMethod
      var reqHeaders: Table[string, seq[string]]
      var vars = ReqVars(code: Http404)

      block outer:
        ## parse first row
        
        let row = await client.recvLine()
        if row == "": break mainLoop
        var rowi = 0
        var methodStr: string
        rowi += row.parseUntil(methodStr, Whitespace, rowi) + 1
        
        meth =
          case methodStr
          of "GET": HttpGet
          of "POST": HttpPost
          else:
            vars.code = Http400
            break outer
        
        var path: string

        if (let ch = row[rowi]; ch in {'\'', '"'}):
          inc rowi, row.parseUntil(path, ch, rowi) + 2
        else:
          inc rowi, row.parseUntil(path, Whitespace, rowi) + 1
        
        vars.pathWithQuery = path

        if meth == HttpGet:
          let i = path.rfind('?')
          if i >= 0:
            vars.params = parseQuery(path, i+1)
            path = path.substr(0, i-1)
        
        if not row.substr(rowi).startsWith("HTTP/1.1"):
          vars.code = Http400
          break outer
        
        ## parse headers
        
        while true:
          let row = await client.recvLine()
          if row == "": break mainLoop
          if row == "\c\L": break
          
          var key: string
          var i = 0
          i += row.parseUntil(key, ':', i) + 2 # skip ": "
          
          if key == "":
            vars.code = Http400
            break outer
          
          key = key.toLowerAscii()
          
          while i <= row.high:
            var val: string
            i += row.parseUntil(val, ',', i) + 1
            
            if val == "":
              vars.code = Http400
              break outer
            
            reqHeaders.mgetOrPut(key, @[]).add val
        
        if meth == HttpPost and "content-length" notin reqHeaders:
          vars.code = Http411
          break outer
        
        ## parse body
        
        if "content-length" in reqHeaders:
          let expectedBytes =
            try:
              reqHeaders["content-length"][0].parseInt()
            except ValueError:
              vars.code = Http411
              break
          
          if expectedBytes > 0:
            let body = await client.recv(expectedBytes)
            
            if body == "":
              break mainLoop 
            
            if body.len != expectedBytes:
              vars.code = Http411
              break outer
            
            if "content-type" notin reqHeaders:
              vars.code = Http400
              break outer
            
            if reqHeaders["content-type"][0] == "multipart/form":
              vars.code = Http404
              break outer
            
            vars.params = parseQuery(body, 0)

        ## parse cookies        
        
        var cookies: Table[string, string]
  
        if "cookie" in reqHeaders:
          for header in reqHeaders["cookie"]:
            for pair in header.split("; "):
              let eq = pair.find('=')
              if eq >= 0:
                let key = pair.substr(0, eq-1)
                let val = pair.substr(eq+1)
                cookies[key] = val
        
        ## get (or create) session
        
        block:
          if sessionKeyCookie in cookies:
            var packedSession, userId: string
            let row = db.getRow(sql"select rowid, data, user from session where key = ?", cookies[sessionKeyCookie])
            row.unpack vars.sessionId, packedSession, userId

            if vars.sessionId != "":
              var i = 0
              for it in vars.session.fields:
                inc i, packedSession.parseUntil(it, '\1', i) + 1

              if vars.session.prevGet == "":
                vars.session.prevGet = "/"

              if userId != "":
                let userEmail = db.getValue(sql"select email from user where rowid = ?", userId)
                if userEmail != "":
                  vars.userId = userId
                  vars.userEmail = userEmail
            
            else:
              let key = $genOid()
              vars.addHeader "Set-Cookie", (sessionKeyCookie & "=" & key)
              vars.sessionId = $db.insertID(sql"insert into session(key, data) values (?, '')", key)
              vars.session.langId = "2" ## english?

        ## try find route
        
        block findRoute:
          if roots[meth] != nil:
            var node = roots[meth]
            var pathi = path.find('/') + 1
            var token: string

            while pathi <= path.high:
              pathi += path.parseUntil(token, '/', pathi) + 1
              
              if token notin node.kids:
                break findRoute
              
              node = node.kids[token]
            
            if ?.node.cb != nil:
              vars.code = Http200
              node.cb vars
              vars.addHeader "Content-Length", $vars.respBody.len
              vars.addHeader "Content-Type", "text/html"
              
              if meth == HttpGet:
                vars.session.notif = ""
                vars.session.notifKind = ""
                vars.session.prevGet = vars.pathWithQuery

              break outer
        
        ## try find file
        
        if meth == HttpGet:
          let filepath = "public" / path
  
          if fileExists(filepath):
            let file = expandFilename(filepath).splitFile()
            
            if file.dir == getAppDir() / "public" and file.ext in extToMime:
              vars.code = Http200
              vars.respBody = readFile filepath
              vars.addHeader "Content-Type", extToMime[file.ext]
              vars.addHeader "Content-Length", $(vars.respBody.len)
        
        ## the resource hasn't been found, do I need this header for browser to say 404?
        
        vars.addHeader "Content-Type", "text/html"
        vars.respBody = $vars.code

      var sessionPacked: string

      for it in vars.session.fields:
        sessionPacked.add it & '\1'
      
      db.exec sql"update session set data = ? where rowid = ?", sessionPacked, vars.sessionId
      
      let resp =
        "HTTP/1.1 " & toUpperAscii($vars.code) & "\n" &
        vars.respHeaders &
        "\r\n" &
        vars.respBody
      
      await client.send resp

      if meth == HttpPost or client.isClosed or
         "Connection" in reqHeaders and cmpIgnoreCase(reqHeaders["Connection"][^1], "keep-alive") != 0:
        
        client.close()
        break mainLoop

proc serve* {.async.} =
  let server = newAsyncSocket()
  server.setSockOpt OptReuseAddr, true
  server.bindAddr Port(8080)
  server.listen()
  addExitProc proc = server.close()
  
  while true:
    asyncCheck serve await server.accept()