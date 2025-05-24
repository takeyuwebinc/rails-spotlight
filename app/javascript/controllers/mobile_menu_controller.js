import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "overlay"]

  connect() {
    // ESCキーでメニューを閉じる
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.enableBodyScroll()
  }

  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.disableBodyScroll()
    document.addEventListener("keydown", this.boundHandleKeydown)
    
    // アニメーション用のクラスを追加
    requestAnimationFrame(() => {
      this.overlayTarget.classList.remove("opacity-0")
      this.overlayTarget.classList.add("opacity-100")
      this.menuTarget.querySelector("[data-mobile-menu-target='modal']").classList.remove("scale-95", "opacity-0")
      this.menuTarget.querySelector("[data-mobile-menu-target='modal']").classList.add("scale-100", "opacity-100")
    })

    // aria-expanded属性を更新
    const button = document.querySelector("[data-mobile-menu-target='button']")
    if (button) {
      button.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    // アニメーション
    this.overlayTarget.classList.remove("opacity-100")
    this.overlayTarget.classList.add("opacity-0")
    this.menuTarget.querySelector("[data-mobile-menu-target='modal']").classList.remove("scale-100", "opacity-100")
    this.menuTarget.querySelector("[data-mobile-menu-target='modal']").classList.add("scale-95", "opacity-0")

    // アニメーション完了後にhiddenクラスを追加
    setTimeout(() => {
      this.menuTarget.classList.add("hidden")
    }, 200)

    this.enableBodyScroll()
    document.removeEventListener("keydown", this.boundHandleKeydown)

    // aria-expanded属性を更新
    const button = document.querySelector("[data-mobile-menu-target='button']")
    if (button) {
      button.setAttribute("aria-expanded", "false")
    }
  }

  // 背景クリックで閉じる
  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // ESCキーで閉じる
  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // bodyのスクロールを無効化
  disableBodyScroll() {
    document.body.style.overflow = "hidden"
  }

  // bodyのスクロールを有効化
  enableBodyScroll() {
    document.body.style.overflow = ""
  }
}
