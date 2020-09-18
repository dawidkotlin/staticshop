import macros, strtabs, strutils, strformat, sets

var
  identToTag {.compileTime.} = newStringTable(modeStyleInsensitive)
  unpairedTags {.compileTime.}: HashSet[string]

static:
  identToTag["tdiv"] = "div"
  identToTag["italic"] = "i"

  for it in ["p", "button", "html", "head", "title", "body", "section", "strong",
             "h1", "h2", "h3", "h4", "h5", "span", "nav", "a", "table", "thead",
             "tr", "th", "td", "tbody", "form", "label", "option", "select", "script",
             "footer", "figure"]:
    identToTag[it] = it
  
  for it in ["img", "input", "br", "hr", "meta", "link", "checkbox"]:
    identToTag[it] = it
    unpairedTags.incl it

macro renderHtml*(body): string =
  let resultVar = genSym(nskVar)
  
  proc process(node: NimNode): NimNode =
    if node.kind == nnkIdent and (let key = node.strVal.toLowerAscii(); key in identToTag):
      let tag = identToTag[key]
      
      if tag in unpairedTags: 
        result = newCall(bindSym"add", resultVar, newLit("</" & tag & ">"))
      else:
        result = newCall(bindSym"add", resultVar, newLit("<" & tag & "></" & tag & ">"))
    
    elif node.kind in CallNodes and (let key = node[0].repr().toLowerAscii(); key in identToTag):
      let tag = identToTag[key]
      result = newStmtList()
      result.add newCall(bindSym"add", resultVar, newLit(&"<{tag}"))
      
      for i in 1 ..< node.len:
        let it = node[i]
        
        if it.kind == nnkExprEqExpr:
          expectKind it[0], {nnkIdent, nnkStrLit, nnkAccQuoted, nnkSym}
          let key = $it[0]
          let val = it[1]
          result.add newCall(bindSym"add", resultVar, newLit(" " & key & "=\""))
          result.add newCall(bindSym"add", resultVar, val)
          result.add newCall(bindSym"add", resultVar, newLit('"'))

        elif it.kind == nnkInfix:
          expectIdent it[0], "?="
          expectKind it[1], {nnkIdent, nnkStrLit, nnkAccQuoted, nnkSym}
          let name = $it[1]
          let cond = it[2]

          result.add:
            newTree(nnkIfStmt,
              newTree(nnkElifBranch, cond,
                newCall(bindSym"add", resultVar, newLit(" " & name & "=\"" & name & '"'))))

        elif it != node.last:
          expectKind it, {nnkExprEqExpr, nnkInfix}

      result.add newCall(bindSym"add", resultVar, newLit('>'))
      
      if node.last.kind notin {nnkExprEqExpr, nnkInfix}:
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