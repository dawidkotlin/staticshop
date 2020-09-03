import dom

proc querySelector(it: Element or Document, query: cstring): Element {.importcpp.}

proc addEventListener(it: Element or Document, event: cstring, callback: proc()) =
  it.addEventListener event, proc(_: Event) = callback()

document.addEventListener "DOMContentLoaded":
  let modal = document.querySelector("#signupModal")
  let showButton = document.querySelector("#showSignupModal")
  let closeButton = modal.querySelector(".modal-close")
  showButton.addEventListener "click": modal.classList.add "is-active"
  closeButton.addEventListener "click": modal.classList.remove "is-active"