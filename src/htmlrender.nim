import macros, strtabs, strutils, strformat, sets

let
  identToTag {.compileTime.} = newStringTable(modeStyleInsensitive)
var
  unpairedTags {.compileTime.}: HashSet[string]

static:
  identToTag["tdiv"] = "div"
  identToTag["italic"] = "i"

  for it in ["p", "button", "html", "head", "title", "body", "section", "strong", "h1", "h2", "h3", "h4", "h5", "span", "nav", "a", "table", "italic", "thead", "tr", "th", "td", "tbody", "form", "label", "option", "select", "script"]:
    identToTag[it] = it
  
  for it in ["img", "input", "br", "hr", "meta", "link", "checkbox"]:
    identToTag[it] = it
    unpairedTags.incl it

macro render*(body): string =
  let resultVar = genSym(nskVar)
  
  proc process(node: NimNode): NimNode =
    
    if node.kind == nnkIdent and (let key = node.strVal.toLowerAscii(); key in identToTag):
      let tag = identToTag[key]
      
      if tag in unpairedTags: 
        result = newCall("add", resultVar, newLit("</" & tag & ">"))
      else:
        result = newCall("add", resultVar, newLit("<" & tag & "></" & tag & ">"))
    
    elif node.kind in CallNodes and (let key = node[0].repr().toLowerAscii(); key in identToTag):
      let tag = identToTag[key]
      result = newStmtList()
      result.add newCall("add", resultVar, newLit(&"<{tag}"))
      
      for i in 1 ..< node.len:
        let it = node[i]
        
        if it.kind == nnkExprEqExpr:
          result.add newCall("add", resultVar, newLit(&" {$it[0]}='"))
          result.add newCall("add", resultVar, it[1])
          result.add newCall("add", resultVar, newLit("'"))
        else:
          assert it == node.last
      
      result.add newCall("add", resultVar, newLit('>'))
      
      if node.last.kind != nnkExprEqExpr:
        result.add process(node.last)
      
      if tag notin unpairedTags:
        result.add newCall(bindSym"add", resultVar, newLit(&"</{tag}>"))
    
    elif node.kind in {nnkIfStmt, nnkCaseStmt}:
      for it in node:
        if it.kind in {nnkElifBranch, nnkOfBranch}:
          it[1][] = process(it[1])[]
        else:
          assert it.kind == nnkElse, $it.kind
          it[0][] = process(it[0])[]
      
      result = node
    
    elif node.kind == nnkForStmt:
      node[2] = process node[2]
      result = node
    
    elif node.kind == nnkStmtList:
      for it in node:
        it[] = process(it)[]
      
      result = node
    
    else:
      let kind = $node.kind
      
      result = quote:
        when compiles(`resultVar`.add `node`): `resultVar`.add `node`
        # elif compiles(`node`): `node`
        # else: {.fatal: `kind`.}
        else: `node`
  
  result = newStmtList(
    newVarStmt(resultVar, newLit("")),
    process(body),
    resultVar)