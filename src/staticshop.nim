import server, asyncdispatch, httpcore, database, strutils, htmlrender

template modal(modalId: string, body): untyped =
  render:
    tdiv(class="modal", id=modalId):
      tdiv(class="modal-background")
      tdiv(class="modal-content"):
        tdiv(class="container"):
          tdiv(class="box"): body
      button(class="modal-close is-large", "aria-label"="close")

const frontendJsSource = staticRead "frontend.js"

template renderPage*(vars: ReqVars, dslBody) =
  vars.respBody = render:
    "<!DOCTYPE html>"
    html:
      head:
        meta(charset="utf-8")
        meta(name="viewport", content="width=device-width, initial-scale=1")
        title "staticshop"
        link(rel="stylesheet", href="https://cdn.jsdelivr.net/npm/bulma@0.9.0/css/bulma.min.css")
        script frontendJsSource
      body:
        modal "signupModal":
          form(action="/signup", "method"="post"):
            tdiv(class="field"):
              label(class="label"): "First name"
              tdiv(class="control"):
                input(class="input", `type`="text", name="firstName")
            tdiv(class="field"):
              label(class="label"): "Second name"
              tdiv(class="control"):
                input(class="input", `type`="text", name="secondName")
            tdiv(class="field"):
              label(class="label"): "Email"
              tdiv(class="control"):
                input(class="input", `type`="email", name="email")
            tdiv(class="field"):
              label(class="label"): "Password"
              tdiv(class="control"):
                input(class="input", `type`="password", name="password")
            tdiv(class="field"):
              label(class="label"): "Confirm password"
              tdiv(class="control"):
                input(class="input", `type`="password", name="confirmPassword")
            tdiv(class="field"):
              tdiv(class="control"):
                button(class="button is-info"): "Sign up"
        nav(class="navbar", role="navigation", "aria-label"="main navigation"):
          tdiv(class="navbar-brand"):
            a(class="navbar-item", href="/"): img(src="https://bulma.io/images/bulma-logo.png", width="112", height="28") 
            a(role="button", class="navbar-burger burger", "aria-label"="menu", "aria-expanded"="false"):
              span("aria-hidden"="true")
              span("aria-hidden"="true")
              span("aria-hidden"="true")
          tdiv(class="navbar-menu"):
            tdiv(class="navbar-end"):
              tdiv(class="navbar-item"):
                tdiv(class="buttons"):
                  button(class="button is-primary", id="showSignupModal"): strong"Sign up"
                  button(class="button is-light"): "Log in"
        section(class="section"):
          tdiv(class="container"): dslBody

addRoute HttpGet, "/", proc(vars: var ReqVars) =
  vars.redirect "/search"

addRoute HttpGet, "/search", proc(vars: var ReqVars) =
  vars.renderPage:
    # h1(class="title"): "Hello World"
    # p(class="subtitle"): "My first website with "; strong"Bulma"; "!"
    tdiv(class="columns"):
      tdiv(class="column is-one-third"):
        form(action="/search"):
          tdiv(class="field"):
            label(class="label"): "Name"
            tdiv(class="control"): input(class="input", "type"="text", name="name")
          tdiv(class="field"):
            label(class="label"): "Category"
            tdiv(class="control"):
              tdiv(class="select"):
                select:
                  discard
                  # for it in rows[[tuple[rowid, name: string]]](sql"select category.rowid, name from category join categoryName on categoryName.category = category.rowid where lang = ?", session.lang):
                  #   option(value=it.rowid): it.name.capitalizeAscii()
      tdiv(class="column"):
        table(class="table is-fullwidth"):
          thead:
            tr:
              th "Name"
              th "Category"
              th "Price"
              th "Premiere"
          tbody:
            for product in rows[tuple[price, premiere, name, desc, category: string]](sql"""
              select price, premiere, productName.name, desc, categoryName.name
              from product
              join productName on productName.product = product.rowid
              join productDesc on productDesc.product = product.rowid
              join categoryName on categoryName.category = product.category
              where productName.lang = ? and productDesc.lang = ? and categoryName.lang = ?""", 2, 2, 2):
              tr:
                td: strong product.name
                td: product.category.capitalizeAscii()
                td: product.price.insertSep(' '); " ZŁ"
                td: product.premiere

addRoute HttpPost, "/signup", proc(vars: var ReqVars) =
  # let firstName = vars.
  discard

echo "Running staticshop server..."
asyncCheck serve()
runForever()