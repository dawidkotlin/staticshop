import dom

proc querySelector(it: Element or Document, query: cstring): Element {.importcpp.}

proc addEventListener(it: Element or Document, event: cstring, callback: proc()) =
  it.addEventListener event, proc(_: Event) = callback()

document.addEventListener "DOMContentLoaded":
  ## signup modal
  for show in document.querySelectorAll("#showSignupModal"):
    let modal = document.querySelector("#signupModal")
    let hide = modal.querySelector(".modal-close")
    show.addEventListener "click": modal.classList.add "is-active"
    hide.addEventListener "click": modal.classList.remove "is-active"
  
  ## login modal
  for show in document.querySelectorAll("#showLoginModal"):
    let modal = document.querySelector("#loginModal")
    let hide = modal.querySelector(".modal-close")
    show.addEventListener "click": modal.classList.add "is-active"
    hide.addEventListener "click": modal.classList.remove "is-active"
  
  ## notifications
  for notif in document.querySelectorAll(".notification"):
    let parent = notif.parentNode
    let close = notif.querySelector(".delete")
    close.addEventListener "click": parent.removeChild notif