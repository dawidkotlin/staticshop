import macros, strtabs, strutils, strformat

let
  tags {.compileTime.} = newStringTable(modeStyleInsensitive)
  unpairedTags {.compileTime.} = newStringTable(modeStyleInsensitive)

static:
  tags["tdiv"] = "div"
  for it in ["p", "button", "html", "head", "title", "link", "body", "section", "strong", "h1", "h2", "h3", "h4", "h5", "span", "nav", "a", "table", "thead", "tr", "th", "td", "tbody", "form", "label", "option", "select", "script"]:
    tags[it] = it
  for it in ["img", "input", "br", "hr", "meta"]:
    tags[it] = it
    unpairedTags[it] = it

macro render*(body): string =
  let resultVar = genSym(nskVar)
  proc process(node: NimNode): NimNode =
    if node.kind in CallNodes and (let key = node[0].repr().toLowerAscii(); key in tags):
      let tag = tags[key]
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
      if node.last.kind != nnkExprEqExpr: result.add process(node.last)
      if tag notin unpairedTags: result.add newCall(bindSym"add", resultVar, newLit(&"</{tag}>"))
    elif node.kind in {nnkIfStmt, nnkCaseStmt}:
      for it in node:
        if it.kind in {nnkElifBranch, nnkOfBranch}:
          it[1][] = process(it[1])[]
        else:
          it[] = process(it)[]
      result = node
    elif node.kind == nnkForStmt:
      node[2] = process node[2]
      result = node
    elif node.kind == nnkStmtList:
      for it in node: it[] = process(it)[]
      result = node
    else:
      result = quote:
        discard
        when compiles(`resultVar`.add `node`): `resultVar`.add `node`
        else: `node`
  result = newStmtList()
  result.add newVarStmt(resultVar, newLit(""))
  result.add process(body)
  result.add resultVar