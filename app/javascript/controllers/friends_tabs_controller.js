import { Controller } from "@hotwired/stimulus"
import { Tab } from "bootstrap"

export default class extends Controller {
  static targets = ["tabButton"]

  connect() {
    const urlTarget = this.targetFromUrlParam()
    if (urlTarget) {
      this.showAndRemember(urlTarget)
      return
    }

    const savedTarget = sessionStorage.getItem(this.storageKey())
    if (!savedTarget) return
    this.showAndRemember(savedTarget)
  }

  remember(event) {
    const target = event.target.getAttribute("data-bs-target")
    if (!target) return

    sessionStorage.setItem(this.storageKey(), target)
    this.updateUrlTabParam(target)
  }

  targetFromUrlParam() {
    const params = new URLSearchParams(window.location.search)
    const tab = params.get("tab")
    if (!tab) return null

    switch (tab) {
      case "friends":
        return "#friends-pane"
      case "received":
        return "#friends-received-pane"
      case "sent":
        return "#friends-sent-pane"
      case "declined":
        return "#friends-declined-pane"
      default:
        return null
    }
  }

  showAndRemember(target) {
    const button = this.tabButtonTargets.find((tabButton) => tabButton.getAttribute("data-bs-target") === target)
    if (!button) return

    Tab.getOrCreateInstance(button).show()
    sessionStorage.setItem(this.storageKey(), target)
    this.updateUrlTabParam(target)
  }

  updateUrlTabParam(target) {
    const tab = this.tabParamForTarget(target)
    if (!tab) return

    const url = new URL(window.location.href)
    url.searchParams.set("tab", tab)
    window.history.replaceState({}, "", url.toString())
  }

  tabParamForTarget(target) {
    switch (target) {
      case "#friends-pane":
        return "friends"
      case "#friends-received-pane":
        return "received"
      case "#friends-sent-pane":
        return "sent"
      case "#friends-declined-pane":
        return "declined"
      default:
        return null
    }
  }

  storageKey() {
    return `friends-active-tab:${window.location.pathname}`
  }
}
