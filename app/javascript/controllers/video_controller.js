import { Controller } from "@hotwired/stimulus"

// The intro video opens in its own window on top of the page, like a second desktop window.
// Close with its button, a click outside it, or Escape. The file is only requested once someone opens it.
export default class extends Controller {
  static targets = ["dialog", "player"]
  static values = { src: String }

  open() {
    if (!this.playerTarget.getAttribute("src")) this.playerTarget.src = this.srcValue
    this.dialogTarget.showModal()
    this.playerTarget.play().catch(() => { /* autoplay refused: the controls are there */ })
  }

  close() { this.dialogTarget.close() }

  // The dialog has no padding, so a click that lands on the dialog element itself is a click on the backdrop.
  backdrop(event) { if (event.target === this.dialogTarget) this.close() }

  // Fires however it closed (button, Escape, backdrop). Closing the window stops the sound.
  closed() { this.playerTarget.pause() }
}
