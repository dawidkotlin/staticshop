import dom

proc querySelector(it: Element or Document, query: cstring): Element {.importcpp.}

proc addModalHandlers(modal, showButton: string) =
  for show in document.querySelectorAll(showButton):
    let modal = document.querySelector(modal)
    let hide = modal.querySelector(".modal-close")
    show.addEventListener "click", proc(_: auto) = modal.classList.add "is-active"
    hide.addEventListener "click", proc(_: auto) = modal.classList.remove "is-active"

addModalHandlers "#signupModal", "#showSignupModal"
addModalHandlers "#loginModal", "#showLoginModal"

for notif in document.querySelectorAll(".notification"):
  let parent = notif.parentNode
  let close = notif.querySelector(".delete")
  close.addEventListener "click", proc(_: auto) = parent.removeChild notif