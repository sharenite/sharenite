import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["advancedFilters", "mobileToggle", "form", "tabInput", "sortInput"]

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
      this.formElement.requestSubmit()
    }, 200)
  }

  currentParams() {
    return new URLSearchParams(new FormData(this.formElement)).toString()
  }

  syncStateFromLink(event) {
    const href = event.currentTarget?.getAttribute("href")
    if (!href) return

    const url = new URL(href, window.location.origin)
    const tab = url.searchParams.get("tab")
    const sort = url.searchParams.get("sort")

    if (this.hasTabInputTarget && tab !== null) {
      this.tabInputTarget.value = tab
    }

    if (this.hasSortInputTarget) {
      this.sortInputTarget.value = sort || ""
    }

    this.lastSubmittedParams = this.currentParams()
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

  get formElement() {
    return this.hasFormTarget ? this.formTarget : this.element
  }
}
