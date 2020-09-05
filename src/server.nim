import tables, httpcore, strutils, parseutils, asyncnet, asyncdispatch, strtabs, strformat, strutils, std/[exitprocs, wrapnils], os, cookies, marshal, db_sqlite, oids, database
import sugar, sequtils

type
  ReqVars* = object
    # session*: tuple[notif, notifKind, prevGetPath: string]
    
    ## session vars
    notif*, notifKind*, prevGetPath*: string
    
    ## request vars
    code*: HttpCode
    params: Table[string, seq[string]]
    respHeaders, respBody*, userRowid*, userEmail*, langRowid*: string
  
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

proc redirect*(vars: var ReqVars, path: string) =
  vars.addHeader "Location", path
  vars.code = Http303

proc param*(vars: var ReqVars, key: string): string =
  let key = key.toLowerAscii()
  
  if key in vars.params:
    result = vars.params[key][0]

iterator params*(vars: var ReqVars, key: string): string =
  let key = key.toLowerAscii()
  
  if key in vars.params:
    for it in vars.params[key]:
      yield it

proc parseQuery(s: string, start: int): Table[string, seq[string]] =
  var i = 0
  
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
      var sessionKey: string
      var vars: ReqVars
      vars.langRowid = "2" ## en
      var reqHeaders: Table[string, seq[string]]
      
      block outer:
        
        ## parse the first row
        
        let row = await client.recvLine()
        
        if row == "":
          break mainLoop
        
        var rowi = 0
        var methodStr: string
        rowi += row.parseUntil(methodStr, Whitespace, rowi) + 1
        
        let meth =
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
        
        if meth == HttpGet:
          let i = path.rfind('?')
          
          if i >= 0:
            vars.params = parseQuery(path, i+1)
            path = path.substr(0, i-1)
        
        if not row.substr(rowi).startsWith("HTTP/1.1"):
          vars.code = Http400
          break outer
        
        ## parse the headers
        
        while true:
          let row = await client.recvLine()
          
          if row == "":
            break mainLoop
          
          if row == "\c\L":
            break
          
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
        
        ## parse the body if there's any
        
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
        
        ## set session vars
        
        block getSession:
          if sessionKeyCookie in cookies:
            let row = database.row[tuple[data, userRowid: string]](sql"select rowid, data, user from session where key = ?", cookies[sessionKeyCookie])
            echo "row.data = ", row.data

            if row.data != "": ## this means the row doesn't exist because the serialized value is never ""
              sessionKey = cookies[sessionKeyCookie]
              # vars = try: to[vars.typeof](row.data) except ValueError: break getSession
              var i = 0
              inc i, row.data.parseUntil(vars.notif, '\0', i) + 1
              inc i, row.data.parseUntil(vars.notifKind, '\0', i) + 1
              inc i, row.data.parseUntil(vars.notifKind, '\0', i) + 1

              if row.userRowid != "":
                let userEmail = db.getValue(sql"select email from user where rowid = ?", row.userRowid)
                
                if userEmail != "":
                  vars.userRowid = row.userRowid
                  vars.userEmail = userEmail

        if sessionKey == "":
          sessionKey = $genOid()

        vars.addHeader "Set-Cookie", sessionKeyCookie & "=" & sessionKey

        if vars.prevGetPath == "":
          vars.prevGetPath = "/"

        ## find route
        
        vars.code = Http404
        
        block findRoute:
          if roots[meth] != nil:
            var node = roots[meth]
            var pathi = path.find('/') + 1
            var token: string
            let queryStart = if (let i = path.rfind('?'); i >= 0): i else: path.high
            
            while pathi < queryStart:
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
                vars.notif = ""
                vars.notifKind = ""
                vars.prevGetPath = path
              
              break outer
        
        ## find file
        
        if meth == HttpGet:
          let filepath = "public" / path
  
          if fileExists(filepath) and (let split = expandFilename(filepath).splitFile(); split.dir == getAppDir() / "public" and split.ext in extToMime):
            vars.code = Http200
            vars.respBody = readFile filepath
            vars.addHeader "Content-Type", extToMime[split.ext]
            vars.addHeader "Content-Length", $(vars.respBody.len)

        vars.code = Http404
      
      assert vars.code != HttpCode(0)
      
      let packedSession = vars.notif & '\0' & vars.notifKind & '\0' & vars.prevGetPath
      
      db.exec sql"replace into session(key, data) values (?, ?)", sessionKey, packedSession

      if client.isClosed or "Connection" in reqHeaders and cmpIgnoreCase(reqHeaders["Connection"][^1], "keep-alive") != 0:
        break mainLoop
      
      let resp = "HTTP/1.1 " & toUpperAscii($vars.code) & "\n" & vars.respHeaders & "\r\n" & vars.respBody
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