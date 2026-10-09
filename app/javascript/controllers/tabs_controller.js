import { Controller } from "@hotwired/stimulus"

// Simple tab group: one panel visible at a time, remembers nothing.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() { this.show(0) }

  pick(event) { this.show(this.tabTargets.indexOf(event.currentTarget)) }

  show(i) {
    this.panelTargets.forEach((el, n) => { el.hidden = n !== i })
    this.tabTargets.forEach((el, n) => el.setAttribute("aria-selected", n === i))
  }
}
