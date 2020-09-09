import server, asyncdispatch, httpcore, database, strutils, htmlrender, sugar, db_sqlite, strutils, uri, oids, bcrypt, os

template modal(modalId: string, body): untyped =
  render:
    tdiv(class="modal", id=modalId):
      tdiv(class="modal-background")
      tdiv(class="modal-content"):
        tdiv(class="container"):
          tdiv(class="box"): body
      button(class="modal-close is-large", "aria-label"="close")

const
  frontendJsSource = staticRead "../frontend.js"

template renderPage*(vars: ReqVars, dslBody) =
  var cartCount, cartPrice: string

  db.getRow(sql"""
    select count(*), sum(price)
    from cartItem
    join product on product.rowid = product
    where user = ?""", vars.userId)
    .unpackTo cartCount, cartPrice

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
              label(class="label"): "Email"
              tdiv(class="control"):
                input(class="input", `type`="email", name="email")

            tdiv(class="field"):
              label(class="label"): "Password"
              tdiv(class="control"):
                input(class="input", `type`="password", name="password", minLength="8")
            
            tdiv(class="field"):
              label(class="label"): "Confirm password"
              tdiv(class="control"):
                input(class="input", `type`="password", name="confirmPassword", minLength="8")
            
            button(class="button is-primary"): strong"Sign up"
        
        modal "loginModal":
          form(action="/login", `method`="post"):
            tdiv(class="field"):
              label(class="label"): "Email"
              tdiv(class="control"):
                input(class="input", `type`="email", name="email")

            tdiv(class="field"):
              label(class="label"): "Password"
              tdiv(class="control"):
                input(class="input", `type`="password", name="password", minLength="8")

            button(class="button is-primary"): strong"Log in"

        nav(class="navbar is-fixed-top", role="navigation", "aria-label"="main navigation"):
          tdiv(class="navbar-brand"):
            a(class="navbar-item", href="/"):
              strong "Home"
            
            a(role="button", class="navbar-burger burger", "aria-label"="menu", "aria-expanded"="false"):
              span("aria-hidden"="true")
              span("aria-hidden"="true")
              span("aria-hidden"="true")
          
          tdiv(class="navbar-menu"):
            tdiv(class="navbar-end"):
              tdiv(class="navbar-item"):
                tdiv(class="field is-grouped"):
                  if vars.userId != "":
                    var cartCount, cartPrice: string

                    db.getRow(sql"""
                      select count(*), sum(price)
                      from cartItem
                      join product on product.rowid = product
                      where user = ?""", vars.userId)
                      .unpackTo cartCount, cartPrice

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
                          strong"Sign up"

                      tdiv(class="control"):  
                        button(class="button is-light", id="showLoginModal"):
                          "Log in"

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
            p:
              "Source code licensed "
              a(href="https://opensource.org/licenses/mit-license.php"): "MIT"
              "."
            p:
              "Website content licensed "
              a(href="https://creativecommons.org/licenses/by-nc-sa/4.0/"): "CC BY-NC-SA 4.0"
              "."
        
        script frontendJsSource

addRoute HttpGet, "/", proc(vars: var ReqVars) =
  vars.addHeader "location", "/search"
  vars.code = Http303

addRoute HttpGet, "/search", proc(vars: var ReqVars) =
  var allCategoryNames, allCategoryRowids: seq[string]
  
  for it in db.fastRows(sql"select rowid, name from categoryName where lang = ?", vars.langRowid):
    allCategoryRowids.add it[0]
    allCategoryNames.add it[1]
  
  var searchedCategoryRowids, searchedCategoryNames: seq[string]
  for it in vars.params("categoryRowid"):
  
    let name = db.getValue(sql"select name from categoryName where rowid = ?", it)
    assert name != "", it
    if name != "":
      searchedCategoryRowids.add it
      searchedCategoryNames.add name
  
  var moviesQuery = """
    select
      product.rowid, price, premiere, productNameImpl.name, desc, categoryName.name, cartItem.rowid, purchase.rowid
    from
      product
      join productName on productName.product = product.rowid
      join productDesc on productDesc.product = product.rowid
      join categoryName on categoryName.category = product.category
      join productNameImpl on productNameImpl.rowid = productName.nameId
      left join cartItem on cartItem.product = product.rowid and cartItem.user = ?
      left join purchase on purchase.product = product.rowid and purchase.user = ?
    where
      productName.lang = ? and
      productDesc.lang = ? and
      categoryName.lang = ? and
      (? == 'false' or purchase.rowid is null) and
      (? == 'false' or cartItem.rowid is not null)
  """
 
  
  let hidePurchased = vars.hasParam("hidePurchased")
  let hideNonCart = vars.hasParam("hideNonCart")
  
  var moviesQueryArgs = @[
    vars.userId,
    vars.userId,
    vars.langRowid,
    vars.langRowid,
    vars.langRowid,
    $hidePurchased,
    $hideNonCart]

  let searchedName = vars.param("searchedName")

  if searchedName != "":
    moviesQuery.add " and productNameImpl match ?"
    moviesQueryArgs.add searchedName

  if searchedCategoryRowids != @[]:
    moviesQuery.add " and product.rowid in (" & repeat("?,", searchedCategoryRowids.len - 1) & "?)"
    moviesQueryArgs.add searchedCategoryRowids
  
  type SortingKind = enum
    skRelevantName = "Most relevant name"
    skRecent = "Most recent first"
    skOld = "Oldest first"
    skExpensive = "Most expensive first"
    skCheap = "Cheapest first"

  # moviesQuery.add " order by purchase.rowid nulls first" # , cartItem.rowid nulls last
  
  var sortingKind =
    if searchedName != "":
      skRelevantName
    else:
      let sorting = vars.param("sortingKind").decodeUrl().parseEnum(default=skRecent)
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
            label(class="label"): "Name"
            tdiv(class="control"):
              input(class="input", `type`="text", name="searchedName", value=searchedName)
          
          tdiv(class="field"):
            label(class="label"): "Sorting"
            tdiv(class="control"):
              tdiv(class="select"):
                select(name="sortingKind"):
                  for it in SortingKind:
                    if it == sortingKind:
                      option(value = $it, selected="selected"): $it
                    else:
                      option(value = $it): $it

          # for it in db.fastRows(sql"""select category.rowid, name
          #                             from category
          #                             join categoryName on categoryName.category = category.rowid
          #                             where lang = ?""", vars.langRowid):
          #   var id, name: string
          #   it.unpackTo id, name
            
          #   tdiv(class"field"):
          #     label(class="label"): "Sci-fi"
          #     tdiv(class="control"):
          #       tdiv(class="select"):
          #         select(name=name):
          #           option(value="")

          tdiv(class="field"):
            label(class="label"): "Categories"
            tdiv(class="control"):
              for it in db.fastRows(sql"""
                  select category.rowid, name
                  from category
                  join categoryName on categoryName.category = category.rowid
                  where lang = ?""", vars.langRowid):
              
                var catRowid, catName: string
                it.unpackTo catRowid, catName 
                
                tdiv:
                  label(class="checkbox"):
                    if catRowid in searchedCategoryRowids:
                      input(`type`="checkbox", name="categoryRowid", value=catRowid, checked="checked"):
                        " "
                        catName.capitalizeAscii()
                    else:
                      input(`type`="checkbox", name="categoryRowid", value=catRowid):
                        " "
                        catName.capitalizeAscii()
              
          tdiv(class="field"):
            label(class="label"): "Other filters"
            tdiv(class="control"):
              tdiv:
                label(class="checkbox"):
                  if hidePurchased:
                    input(`type`="checkbox", name="hidePurchased", checked="checked"):
                      " Hide purchased"
                  else:
                    input(`type`="checkbox", name="hidePurchased"):
                      " Hide purchased"
              
              tdiv:
                label(class="checkbox"):
                  if hideNonCart:
                    input(`type`="checkbox", name="hideNonCart", checked="checked"):
                      " Only cart"
                  else:
                    input(`type`="checkbox", name="hideNonCart"):
                      " Only cart"
          
          button(class="button is-link"): "Search"

      tdiv(class="column"):
        if searchedName != "" or searchedCategoryNames != @[]:
          p(class="subtitle"):
            "Searching"
            
            if searchedName != "":
              " for "
              strong searchedName
            
            if searchedCategoryNames != @[]:
              " in "
              
              for i in 0 ..< searchedCategoryNames.high:
                strong searchedCategoryNames[i]
                ", "
              
              strong searchedCategoryNames[^1] 
        
        table(class="table is-fullwidth"):
          thead:
            tr:
              th"Name"
              th"Category"
              th"Price"
              th"Premiere"
              
              if vars.userId != "":
                th"Cart"
          
          tbody:
            for it in db.fastRows(sql(moviesQuery), moviesQueryArgs):
              var rowid, price, premiere, name, desc, categoryName, cartItemId, purchaseId: string
              it.unpackTo rowid, price, premiere, name, desc, categoryName, cartItemId, purchaseId
              price = price.insertSep(' ') & " zł"

              tr:
                td:
                  if sortingKind == skRelevantName:
                    strong name
                  else:
                    name
                
                td categoryName.capitalizeAscii()
                
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
    .unpackTo userId, passHash, passSalt
  
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
      limit 1""", prodId, vars.userId, prodId).unpackTo name, inCart

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

echo "[ Running staticshop server... ]"
asyncCheck serve()
runForever()