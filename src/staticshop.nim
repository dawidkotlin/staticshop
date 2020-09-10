import server, asyncdispatch, httpcore, database, strutils, htmlrender, sugar, db_sqlite, uri, oids, bcrypt, os, macros

proc translated(vars: ReqVars, phrase: string): string =
  result = db.getValue(sql"select translated from translation where phrase = ? and langId = ?", phrase, vars.langId)

template modal(modalId: string, body): untyped =
  render:
    tdiv(class="modal", id=modalId):
      tdiv(class="modal-background")
      tdiv(class="modal-content"):
        tdiv(class="container"):
          tdiv(class="box"): body
      button(class="modal-close is-large", "aria-label"="close")

const
  frontendJsSource = staticRead getCurrentDir()/"bin"/"frontend.js"

template renderPage*(vars: ReqVars, dslBody) =
  var cartCount, cartPrice: string

  db.getRow(sql"""
    select count(*), sum(price)
    from cartItem
    join product on product.rowid = product
    where user = ?""", vars.userId)
    .unpack cartCount, cartPrice

  vars.respBody = render:
    "<!doctype html>"
    html(class="has-navbar-fixed-top"):
      head:
        meta(charset="utf-8")
        meta(name="viewport", content="width=device-width, initial-scale=1")
        title "staticshop"
        link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/bulma@0.9.0/css/bulma.min.css")
        link(rel="stylesheet", href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.14.0/css/all.min.css")
      
      body:
        modal "signupModal":
          form(action="/signup", `method`="post"):
            tdiv(class="field"):
              label(class="label"):
                vars.translated("email").capitalizeAscii()
              tdiv(class="control"):
                input(class="input", `type`="email", name="email")

            tdiv(class="field"):
              label(class="label"):
                vars.translated("password").capitalizeAscii()
              tdiv(class="control"):
                input(class="input", `type`="password", name="password", minLength="8")
            
            tdiv(class="field"):
              label(class="label"):
                vars.translated("confirm password").capitalizeAscii()
              tdiv(class="control"):
                input(class="input", `type`="confirm password", name="confirmPassword", minLength="8")
            
            button(class="button is-primary"):
              strong vars.translated("sign up")
        
        modal "loginModal":
          form(action="/login", `method`="post"):
            tdiv(class="field"):
              label(class="label"):
                vars.translated("email").capitalizeAscii()
              tdiv(class="control"):
                input(class="input", `type`="email", name="email")

            tdiv(class="field"):
              label(class="label"):
                vars.translated("password").capitalizeAscii()
              tdiv(class="control"):
                input(class="input", `type`="password", name="password", minLength="8")

            button(class="button is-primary"):
              strong vars.translated("log in").capitalizeAscii()

        nav(class="navbar is-fixed-top", role="navigation", "aria-label"="main navigation"):
          tdiv(class="navbar-brand"):
            a(class="navbar-item", href="/"):
              strong "Home"
            
            a(role="button", class="navbar-burger burger", "aria-label"="menu", "aria-expanded"="false"):
              span("aria-hidden"="true")
              span("aria-hidden"="true")
              span("aria-hidden"="true")
          
          tdiv(class="navbar-menu"):
            tdiv(class="navbar-start"):
              tdiv(class="navbar-item"):
                tdiv(class="field is-grouped"):
                  tdiv(class="control"):
                    tdiv(class="dropdown is-hoverable"):
                      tdiv(class="navbar-trigger"):
                        button(class="button", "aria-haspopup"="true", "aria-controls"="dropdown-menu"):
                          span db
                            .getValue(sql"select name from lang where rowid = ?", vars.langId)
                            .capitalizeAscii()
                          
                          span(class="icon is-small"):
                            italic(class="fas fa-angle-down", "aria-hidden"="true")
                      
                      tdiv(class="dropdown-menu", id="dropdown-menu", role="menu"):
                        tdiv(class="dropdown-content"):
                          for it in db.fastRows(sql"select rowid, name from lang", vars.langId):
                            var langId, langName: string
                            it.unpack langId, langName
                            
                            form(action="/changeLang", `method`="post"):
                              input(`type`="hidden", name="langId", value=langId)
                              
                              a(class="dropdown-item", onClick="parentNode.submit()"):
                                langName.capitalizeAscii()

            tdiv(class="navbar-end"):
              tdiv(class="navbar-item"):
                tdiv(class="field is-grouped"):
                  if vars.userId != "":
                    var cartCount, cartPrice: string

                    db.getRow(sql"""
                      select count(*), sum(price)
                      from cartItem
                      join product on product.rowid = product
                      where user = ?""", vars.userId).unpack cartCount, cartPrice

                    if cartCount != "0":
                      tdiv(class="control"):
                        form(action="/removeAllCartItems", `method`="post"):
                          button(class="button is-danger"):
                            "Remove all cart items"
                      
                      tdiv(class="control"):
                        form(action="/buyCartItems", `method`="post"):
                          button(class="button is-success"):
                            "Buy "
                            cartCount
                            if cartCount == "1": " item" else: " items"
                            " for "
                            cartPrice.insertSep(' ')
                            " zł"

                    tdiv(class="control"):
                      form(action="/logout", `method`="post"):
                        button(class="button is-light"):
                          "Log out from " & vars.userEmail

                  else:
                      tdiv(class="control"):
                        button(class="button is-primary", id="showSignupModal"):
                          strong vars.translated("sign up").capitalizeAscii()

                      tdiv(class="control"):  
                        button(class="button is-light", id="showLoginModal"):
                          vars.translated("log in").capitalizeAscii()

        section(class="section"):
          tdiv(class="container"):
            if vars.notif != "":
              tdiv(class="notification " & vars.notifKind):
                button(class="delete")
                vars.notif.capitalizeAscii()
            
            dslBody
        
        footer(class="footer"):
          tdiv(class="content has-text-centered"):
            p:
              "Made in "
              a(href="https://nim-lang.org/"): "Nim"
              " with "
              a(href="https://bulma.io/"): "Bulma"
              " by "
              a(href="#"): "Dawid Kotliński"
              ". The source code licensed "
              a(href="https://opensource.org/licenses/mit-license.php"): "MIT"
              ". The website content licensed "
              a(href="https://creativecommons.org/licenses/by-nc-sa/4.0/"): "CC BY-NC-SA 4.0"
              "."
        
        script frontendJsSource

addRoute HttpGet, "/", proc(vars: var ReqVars) =
  vars.addHeader "location", "/search"
  vars.code = Http303

addRoute HttpGet, "/search", proc(vars: var ReqVars) =
  var catNames, catIds: seq[string]
  
  for it in db.fastRows(sql"select rowid, name from categoryName where lang = ?", vars.langId):
    catIds.add it[0]
    catNames.add it[1]
  
  var searchedCatIds, searchedCatNames: seq[string]
  
  for catId in vars.params("categoryRowid"):
    let catName = db.getValue(sql"select name from categoryName where rowid = ?", catId)
    assert catName != "", catId
    if catName != "":
      searchedCatIds.add catId
      searchedCatNames.add catName
  
  var moviesQuery = """
    select
      product.rowid, price, premiere, productNameImpl.name, categoryName.name, cartItem.rowid, purchase.rowid
    from
      product
      join productName on productName.product = product.rowid
      join categoryName on categoryName.category = product.category
      join productNameImpl on productNameImpl.rowid = productName.nameId
      left join cartItem on cartItem.product = product.rowid and cartItem.user = ?
      left join purchase on purchase.product = product.rowid and purchase.user = ?
    where
      productName.lang = ? and
      categoryName.lang = ? and
      (? like 'exclude' and purchase.rowid is null or ? like 'require' and purchase.rowid is not null or ? = '') and
      (? like 'exclude' and cartItem.rowid is null or ? like 'require' and cartItem.rowid is not null or ? = '')
  """
  
  let purchasedItems = vars.param("purchasedItems")
  let cartItems = vars.param("cartItems")
  
  var moviesQueryArgs = @[
    vars.userId,
    vars.userId,
    vars.langId,
    vars.langId,
    purchasedItems,
    purchasedItems,
    purchasedItems,
    cartItems,
    cartItems,
    cartItems]

  let searchedName = vars.param("searchedName")

  if searchedName != "":
    moviesQuery.add " and productNameImpl match ?"
    moviesQueryArgs.add searchedName

  if searchedCatIds != @[]:
    moviesQuery.add " and product.rowid in (" & repeat("?,", searchedCatIds.len - 1) & "?)"
    moviesQueryArgs.add searchedCatIds
  
  type SortingKind = enum
    skRelevantName = "most relevant name"
    skRecent = "most recent"
    skOld = "oldest"
    skExpensive = "most expensive"
    skCheap = "cheapest"

  # moviesQuery.add " order by purchase.rowid nulls first" # , cartItem.rowid nulls last
  
  var sortingKind =
    if searchedName != "":
      skRelevantName
    else:
      let sorting = vars.param("sortingKind").decodeUrl().parseEnum(skRecent)
      if sorting == skRelevantName:
        skRecent
      else:
        sorting

  case sortingKind
  of skRelevantName: moviesQuery.add "order by rank"
  of skExpensive: moviesQuery.add "order by price desc"
  of skCheap: moviesQuery.add "order by price asc"
  of skRecent: moviesQuery.add "order by premiere desc"
  of skOld: moviesQuery.add "order by premiere asc"

  vars.renderPage:
    tdiv(class="columns"):
      tdiv(class="column is-one-quarter"):
        form(action="/search"):
          tdiv(class="field"):
            label(class="label"): vars.translated("name").capitalizeAscii()
            tdiv(class="control"):
              input(class="input", `type`="text", name="searchedName", value=searchedName)
          
          tdiv(class="field"):
            label(class="label"):
              vars.translated("sorting").capitalizeAscii()
            
            tdiv(class="control"):
              tdiv(class="select"):
                select(name="sortingKind"):
                  for it in SortingKind:
                    if not (it == skRelevantName and searchedName == ""):
                      option(value = $it, selected ?= it == sortingKind):
                        vars.translated($it).capitalizeAscii()

          # for it in db.fastRows(sql"""select category.rowid, name
          #                             from category
          #                             join categoryName on categoryName.category = category.rowid
          #                             where lang = ?""", vars.langRowid):
          #   var id, name: string
          #   it.unpack id, name
            
          #   tdiv(class="field"):
          #     label(class="label"): name
          #     tdiv(class="control"):
          #       tdiv(class="select"):
          #         select(name="catId:"&id):
          #           option(class="has-text-light", value="default"): "Show"
          #           option(class="has-text-green", value="require"): "Require"
          #           option(class="has-text-red", value="exclude"): "Exclude"

          tdiv(class="field"):
            label(class="label"):
              vars.translated("categories").capitalizeAscii()
            
            tdiv(class="control"):
              for it in db.fastRows(sql"""select category.rowid, name
                                          from category
                                          join categoryName on categoryName.category = category.rowid
                                          where lang = ?""", vars.langId):
                var catRowid, catName: string
                it.unpack catRowid, catName 
                
                tdiv:
                  label(class="checkbox"):
                    input(`type`="checkbox", name="categoryRowid", value=catRowid, checked ?= catRowid in searchedCatIds):
                      " "
                      catName.capitalizeAscii()

          tdiv(class="field"):
            label(class="label"):
              vars.translated("purchased items").capitalizeAscii()
            
            tdiv(class="control"):
              tdiv(class="select"):
                select(name="purchasedItems"):
                  option(value="", selected ?= purchasedItems == ""): vars.translated("included").capitalizeAscii()
                  option(value="require", selected ?= purchasedItems == "require"): vars.translated("required").capitalizeAscii()
                  option(value="exclude", selected ?= purchasedItems == "exclude"): vars.translated("excluded").capitalizeAscii()

          tdiv(class="field"):
            label(class="label"):
              vars.translated("cart items").capitalizeAscii()
            
            tdiv(class="control"):
              tdiv(class="select"):
                select(name="cartItems"):
                  option(value="", selected ?= cartItems == ""): vars.translated("included").capitalizeAscii()
                  option(value="require", selected ?= cartItems == "require"): vars.translated("required").capitalizeAscii()
                  option(value="exclude", selected ?= cartItems == "exclude"): vars.translated("excluded").capitalizeAscii()

          # tdiv(class="field"):
          #   label(class="label"): "Other filters"
          #   tdiv(class="control"):
          #     tdiv:
          #       label(class="checkbox"):
          #         input(`type`="checkbox", name="hidePurchased", checked ?= hidePurchased):
          #           " Hide purchased"
          #     tdiv:
          #       label(class="checkbox"):
          #         input(`type`="checkbox", name="hideNonCart", checked ?= hideNonCart):
          #           " Only cart"
          
          button(class="button is-link"):
            vars.translated("search").capitalizeAscii()

      tdiv(class="column"):
        if searchedName != "" or searchedCatNames != @[]:
          p(class="subtitle"):
            "Searching"
            
            if searchedName != "":
              " for "
              strong searchedName
            
            if searchedCatNames != @[]:
              " in "
              
              for i in 0 ..< searchedCatNames.high:
                strong searchedCatNames[i]
                ", "
              
              strong searchedCatNames[^1] 
        
        if db.getValue(sql("select exists(" & moviesQuery & ")"), moviesQueryArgs) == "0":
          section(class="hero"):
            tdiv(class="hero-body"):
              tdiv(class="container"):
                h1(class="title"):
                  "No items match your query"

        else:
          table(class="table is-fullwidth"):
            thead:
              tr:
                th vars.translated("name").capitalizeAscii()
                th vars.translated("category").capitalizeAscii()
                th vars.translated("price").capitalizeAscii()
                th vars.translated("premiere").capitalizeAscii()
                
                if vars.userId != "":
                  th vars.translated("cart").capitalizeAscii()
            
            tbody:
              for it in db.fastRows(sql(moviesQuery), moviesQueryArgs):
                var rowid, price, premiere, name, categoryName, cartItemId, purchaseId: string
                it.unpack rowid, price, premiere, name, categoryName, cartItemId, purchaseId
                price = price.insertSep(' ') & ' ' & vars.translated("PLN")

                tr:
                  td:
                    if sortingKind == skRelevantName:
                      strong name
                    else:
                      name
                  
                  td:
                    categoryName.capitalizeAscii()
                  
                  td:
                    if sortingKind in {skCheap, skExpensive}:
                      strong price
                    else:
                      price

                  td:
                    if sortingKind in {skOld, skRecent}:
                      strong premiere
                    else:
                      premiere
                  
                  if vars.userId != "":
                    td:
                      if purchaseId == "":
                        form(action="/addOrRemoveCartItem", `method`="post"):
                          input(`type`="hidden", name="productId", value=rowid)
                          
                          if cartItemId == "":
                            button(class="button is-small is-success"):
                              "Add"
                          else:
                            button(class="button is-danger is-small"):
                              "Remove"
                      
                      else:
                        button(class="button is-static is-small"):
                          "Purchased"

addRoute HttpGet, "/item", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

addRoute HttpPost, "/signup", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303
  let email = vars.param("email")

  if db.getValue(sql"select exists(select 1 from user where email = ?)", email) == "1":
    vars.notif = "Email <strong>" & email & "</strong> has already been taken"
    vars.notifKind = "is-danger"
  else:
    let pass = vars.param("password")
    let salt = genSalt(10)
    let hashed = pass.hash(salt)
    let userId = db.insertID(sql"insert into user(email, passHash, passSalt) values(?, ?, ?)", email, hashed, salt)
    db.exec sql"update session set user = ? where rowid = ?", userId, vars.sessionId
    vars.notif = "Signed up successfully"
    vars.notifKind = "is-success"

addRoute HttpPost, "/login", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303
  let email = vars.param("email")
  var userId, passHash, passSalt: string
  
  db.getRow(sql"select rowid, passHash, passSalt from user where email = ?", email)
    .unpack userId, passHash, passSalt
  
  if passHash == "" or passSalt == "":
    vars.notif = "Invalid email"
    vars.notifKind = "is-danger"
  
  else: 
    let pass = vars.param("password")
    let hashed = pass.hash(passSalt)
    
    if hashed == passHash:
      db.exec sql"update session set user = ? where rowid = ?", userId, vars.sessionId

addRoute HttpPost, "/logout", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

  if vars.userId != "":
    db.exec sql"update session set user = NULL where rowid = ?", vars.userId
    vars.notif = "Logged out from " & vars.userEmail
    vars.notifKind = "is-info"

addRoute HttpPost, "/addOrRemoveCartItem", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303
  let prodId = vars.param("productId")
  
  if vars.userId != "":
    var name, inCart: string

    db.getRow(sql"""
      select name, exists(select * from cartItem where product = ? and user = ?)
      from productName
      join productNameImpl on productNameImpl.rowid = productName.nameId
      where product = ?
      limit 1""", prodId, vars.userId, prodId).unpack name, inCart

    if inCart == "1":
      vars.notif = "Removed <strong>" & name & "</strong>"
      db.exec sql"delete from cartItem where product = ? and user = ?", prodId, vars.userId
    else:
      vars.notif = "Added <strong>" & name & "</strong>"
      db.exec sql"insert into cartItem(product, user) values(?, ?)", prodId, vars.userId

addRoute HttpPost, "/buyCartItems", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

  if vars.userId != "" and db.getValue(sql"select count(*) from cartItem where user = ?", vars.userId) != "0":
    db.exec sql"""
      insert into purchase(user, product)
      select user, product
      from cartItem
      where user = ?""", vars.userId

    db.exec sql"delete from cartItem where user = ?", vars.userId
    vars.notif = "Purchase completed"
    vars.notifKind = "is-success"

addRoute HttpPost, "/removeAllCartItems", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

  if vars.userId != "":
    db.exec sql"delete from cartItem where user = ?", vars.userId
    vars.notif = "Removed all cart items"

addRoute HttpPost, "/changeLang", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303
  vars.langId = vars.param("langId")

echo "The server has started"
asyncCheck serve()
runForever()