import { Controller } from "@hotwired/stimulus"

// Tabbed API-response demo. All panels share one grid cell (see .stack), so the block keeps the height of the tallest
// panel and the page below never jumps when it rotates. Rotates on its own until the visitor picks a tab.
export default class extends Controller {
  static targets = ["state", "code", "tab"]

  connect() {
    this.index = 0
    this.render()
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return
    this.timer = setInterval(() => this.select((this.index + 1) % this.stateTargets.length), 5000)
  }

  disconnect() { clearInterval(this.timer) }

  pick(event) {
    clearInterval(this.timer)
    this.select(this.tabTargets.indexOf(event.currentTarget))
  }

  select(i) { this.index = i; this.render() }

  render() {
    this.stateTargets.forEach((el, n) => { el.dataset.active = String(n === this.index) })
    this.codeTargets.forEach((el, n) => { el.dataset.active = String(n === this.index) })
    this.tabTargets.forEach((el, n) => el.setAttribute("aria-selected", n === this.index))
  }
}
