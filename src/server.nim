import tables, httpcore, strutils, parseutils, asyncnet, asyncdispatch, strtabs, strformat, strutils, std/[exitprocs, wrapnils], os, cookies, marshal, db_sqlite, oids, database
import sugar, sequtils

type
  ReqVars* = object
    session*: tuple[notif, notifKind, prevGetPath: string]
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
        ## parse first row
        
        # var pathWithoutQuery: string
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
        
        # var pathWithQuery: string
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
        
        ## parse headers
        
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
        
        ## parse body if there's any
        
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
        
        ## get or create session vars
        
        if "Cookie" in reqHeaders:
          let cookies = reqHeaders["Cookie"][0].parseCookies()
          
          if cookies != nil and sessionKeyCookie in cookies:
            sessionKey = cookies[sessionKeyCookie]
            let row = database.row[tuple[data, userRowid: string]](sql"select rowid, data, user from session where key = ?", sessionKey)
            
            if row.userRowid != "":
              vars.userEmail = db.getValue(sql"select email from user where rowid = ?", vars.userRowid)
              
              if vars.userEmail != "":
                vars.userRowid = row.userRowid
              
              vars.session = to[vars.session.typeof](row.data)
        
        if vars.session.prevGetPath == "":
          vars.session.prevGetPath = "/"
        
        vars.code = Http404
        
        ## find route
        
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
                reset vars.session
                vars.session.prevGetPath = path
              
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
      
      if sessionKey == "":
        sessionKey = $genOid()
      
      vars.session.notif = ""
      vars.session.notifKind = ""

      db.exec sql"replace into session(key, data) values (?, ?)", sessionKey, $$vars.session
      
      if client.isClosed or "Connection" in reqHeaders and reqHeaders["Connection"][0].toLowerAscii() != "keep-alive":
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