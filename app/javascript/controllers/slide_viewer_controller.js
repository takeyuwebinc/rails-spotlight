import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static values = { current: Number, total: Number }
  
  connect() {
    // キーボードイベントのリスナー追加
    document.addEventListener("keydown", this.handleKeydown.bind(this))
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown.bind(this))
  }
  
  handleKeydown(event) {
    switch(event.key) {
      case "ArrowLeft":
        this.previousSlide()
        break
      case "ArrowRight":
        this.nextSlide()
        break
    }
  }
  
  previousSlide() {
    if (this.currentValue > 1) {
      window.location.href = `/slides/${this.slideSlug}?page=${this.currentValue - 1}`
    }
  }
  
  nextSlide() {
    if (this.currentValue < this.totalValue) {
      window.location.href = `/slides/${this.slideSlug}?page=${this.currentValue + 1}`
    }
  }
  
  get slideSlug() {
    return window.location.pathname.split("/")[2]
  }
}