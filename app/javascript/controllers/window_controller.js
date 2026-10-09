import { Controller } from "@hotwired/stimulus"

// The page lives in a desktop-style window. Maximize makes it full-bleed (remembered per browser);
// close hides it and leaves just the illustration behind. A page change (the Home icon, any menubar link)
// always brings a closed window back, and so does Escape or the keyboard-only "Reopen" button.
export default class extends Controller {
  static targets = ["window", "chip", "maxButton"]

  connect() { this.apply(this.storedMax() ? "max" : "normal") }

  toggleMax() {
    const next = this.state === "max" ? "normal" : "max"
    this.store(next === "max")
    this.apply(next)
  }

  close() { this.apply("closed") }

  // With the window closed there is nothing on screen but the scene, so Escape brings it back.
  escape(event) {
    // An open video window takes Escape for itself.
    if (event.key === "Escape" && this.state === "closed" && !document.querySelector("dialog[open]")) this.reopen()
  }

  reopen() {
    this.apply(this.storedMax() ? "max" : "normal")
    this.maxButtonTarget.focus()
  }

  apply(state) {
    this.state = state
    this.element.dataset.state = state
    this.windowTarget.hidden = state === "closed"
    this.chipTarget.hidden = state !== "closed"
    const max = state === "max"
    this.maxButtonTarget.setAttribute("aria-pressed", String(max))
    this.maxButtonTarget.setAttribute("aria-label", max ? "Restore window size" : "Maximize window")
    this.maxButtonTarget.title = max ? "Restore" : "Maximize"
  }

  storedMax() {
    try { return localStorage.getItem("opentrust.window") === "max" } catch { return false }
  }

  store(max) {
    try { max ? localStorage.setItem("opentrust.window", "max") : localStorage.removeItem("opentrust.window") } catch { /* private mode */ }
  }
}
