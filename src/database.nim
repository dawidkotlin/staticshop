import db_sqlite, macros

let
  db* = db_sqlite.open(connection="private/data.db", user="", password="", database="")

macro unpack*(row: seq[string], vars: varargs[untyped]) =
  template asgn(thisVar, row, i) =
    thisVar = if i <= row.high: row[i] else: ""
  
  result = newStmtList()
  for i in 0 ..< vars.len:
    result.add getAst asgn(vars[i], row, i)