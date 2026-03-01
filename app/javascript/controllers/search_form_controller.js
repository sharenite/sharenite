import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["advancedFilters", "mobileToggle"]

  connect() {
    this.restoreAdvancedFiltersState()
    this.lastSubmittedParams = this.currentParams()
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const params = this.currentParams()
      if (params === this.lastSubmittedParams) return

      this.lastSubmittedParams = params
      this.element.requestSubmit()
    }, 200)
  }

  currentParams() {
    return new URLSearchParams(new FormData(this.element)).toString()
  }

  rememberOpen() {
    sessionStorage.setItem("gamesAdvancedFiltersOpen", "1")
  }

  rememberClosed() {
    sessionStorage.setItem("gamesAdvancedFiltersOpen", "0")
  }

  rememberResetState() {
    if (!this.isMobileViewport()) return

    const isOpen = this.hasAdvancedFiltersTarget && this.advancedFiltersTarget.classList.contains("show")
    sessionStorage.setItem("gamesAdvancedFiltersOpen", isOpen ? "1" : "0")
  }

  restoreAdvancedFiltersState() {
    if (!this.isMobileViewport()) return
    if (!this.hasAdvancedFiltersTarget || !this.hasMobileToggleTarget) return
    if (sessionStorage.getItem("gamesAdvancedFiltersOpen") !== "1") return

    this.advancedFiltersTarget.classList.add("show")
    this.mobileToggleTarget.setAttribute("aria-expanded", "true")
  }

  isMobileViewport() {
    return window.matchMedia("(max-width: 991.98px)").matches
  }
}
