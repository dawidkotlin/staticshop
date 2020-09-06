import server, asyncdispatch, httpcore, database, strutils, htmlrender, sugar, db_sqlite, strutils, uri, oids, bcrypt, os

template modal(modalId: string, body): untyped =
  render:
    tdiv(class="modal", id=modalId):
      tdiv(class="modal-background")
      tdiv(class="modal-content"):
        tdiv(class="container"):
          tdiv(class="box"): body
      button(class="modal-close is-large", "aria-label"="close")

const frontendJsSource = staticRead "../frontend.js"

template renderPage*(vars: ReqVars, dslBody) =
  vars.respBody = render:
    "<!DOCTYPE html>"
    html:
      head:
        meta(charset="utf-8")
        meta(name="viewport", content="width=device-width, initial-scale=1")
        title "staticshop"
        link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/bulma@0.9.0/css/bulma.min.css")
        link(rel="stylesheet", href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.14.0/css/all.min.css")
        script frontendJsSource
      
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
            
            # tdiv(class="field"):
            #   tdiv(class="control"):
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

        nav(class="navbar", role="navigation", "aria-label"="main navigation"):
          tdiv(class="navbar-brand"):
            a(class="navbar-item", href="/"):
              img(src="https://bulma.io/images/bulma-logo.png", width="112", height="28") 
            
            a(role="button", class="navbar-burger burger", "aria-label"="menu", "aria-expanded"="false"):
              span("aria-hidden"="true")
              span("aria-hidden"="true")
              span("aria-hidden"="true")
          
          tdiv(class="navbar-menu"):
            tdiv(class="navbar-end"):
              
              if vars.userRowid != "":
                tdiv(class="navbar-item"):
                  tdiv(class="field is-grouped"):
                    tdiv(class="control"):
                      form(action="/logout", `method`="post"):
                        button(class="button is-light"): "Log out"
                    
                    tdiv(class="control"):
                      button(class="button is-static"): vars.userEmail

              else:
                tdiv(class="navbar-item"):
                  tdiv(class="buttons"):
                    button(class="button is-primary", id="showSignupModal"): strong"Sign up"
                    button(class="button is-light", id="showLoginModal"): "Log in"

        section(class="section"):
          tdiv(class="container"):
            if vars.notif != "":
              tdiv(class="notification " & vars.notifKind):
                button(class="delete")
                vars.notif
            
            dslBody

addRoute HttpGet, "/", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

addRoute HttpGet, "/search", proc(vars: var ReqVars) =
  let searchedName = vars.param("name")
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
      product.rowid, price, premiere, productName.name, desc, categoryName.name, purchase.rowid
    from
      product
      join productName on productName.product = product.rowid
      join productDesc on productDesc.product = product.rowid
      join categoryName on categoryName.category = product.category
      left join purchase on purchase.product = product.rowid
    where
      productName.lang = ? and
      productDesc.lang = ? and
      categoryName.lang = ?"""
  
  var moviesQueryArgs = @[vars.langRowid, vars.langRowid, vars.langRowid]
  
  if searchedCategoryRowids != @[]:
    moviesQuery.add " and product.rowid in (" & repeat("?,", searchedCategoryRowids.len-1) & "?)"
    moviesQueryArgs.add searchedCategoryRowids
  
  type SortingKind = enum
    skCategory="By category"
    skExpensive="Expensive first"
    skCheap="Cheap first"
    skRecent="Recent first"
    skOld="Old first"

  let sortingKind = vars.param("sortingKind").decodeUrl().parseEnum(default=skRecent)
  
  case sortingKind
  of skCategory: moviesQuery.add " order by product.category"
  of skExpensive: moviesQuery.add " order by price desc"
  of skCheap: moviesQuery.add " order by price asc"
  of skRecent: moviesQuery.add " order by premiere desc"
  of skOld: moviesQuery.add " order by premiere asc"

  vars.renderPage:
    tdiv(class="columns"):
      tdiv(class="column is-one-quarter"):
        # h1(class="title"): "Search"
        
        form(action="/search"):
          tdiv(class="field"):
            label(class="label"): "Name"
            tdiv(class="control"): input(class="input", `type`="text", name="name", value=searchedName)
          
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
          
          button(class="button is-info"): "Search"

      tdiv(class="column"):
        # h1(class="title"): "Movies"
        
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
        
        table(class="table is-fullwidth is-hoverable"):
          thead:
            tr:
              th "Name"
              th "Category"
              th "Price"
              th "Premiere"
              
              if vars.userRowid != "":
                th "Cart"
          
          tbody:
            for it in db.fastRows(sql(moviesQuery), moviesQueryArgs):
              var rowid, price, premiere, name, desc, categoryName, purchaseRowid: string
              it.unpackTo rowid, price, premiere, name, desc, categoryName, purchaseRowid
              
              tr:
                td: strong name
                td: categoryName.capitalizeAscii()
                td: price.insertSep(' '); " zł"
                td: premiere
                
                if vars.userRowid != "":
                  td:
                    if purchaseRowid == "":
                      form(action="/addToCart", `method`="post"):
                        input(`type`="hidden", name="productId", value=rowid)
                        button(class="button is-success is-small"): "Add"
                    else:
                      form(action="/removeFromCart", `method`="post"):
                        input(`type`="hidden", nmae="productId", value=rowid)
                        button(class="button is-danger is-small"): "Remove"

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
    vars.notif = """Signed up successfully"""
    vars.notifKind = "is-success"

addRoute HttpPost, "/login", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303
  let email = vars.param("email")
  var userRowid, passHash, passSalt: string
  
  db.getRow(sql"select rowid, passHash, passSalt from user where email = ?", email)
    .unpackTo userRowid, passHash, passSalt
  
  if passHash == "" or passSalt == "":
    vars.notif = "Invalid email"
    vars.notifKind = "is-danger"
  
  else: 
    let pass = vars.param("password")
    let hashed = pass.hash(passSalt)
    
    if hashed == passHash:
      db.exec sql"update session set user = ? where rowid = ?", userRowid, vars.sessionId

addRoute HttpPost, "/logout", proc(vars: var ReqVars) =
  vars.addHeader "location", vars.prevGetPath
  vars.code = Http303

  if vars.userRowid != "":
    db.exec sql"update session set user = NULL where rowid = ?", vars.userRowid
    vars.notif = "You have been logged out"

echo "  Running staticshop server..."
asyncCheck serve()
runForever()