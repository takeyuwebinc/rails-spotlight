import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    theme: String,
  }
  static targets = ["sunIcon", "moonIcon"];

  connect() {
    document.documentElement.classList.add(this.themeValue);
    document.documentElement.style.colorScheme = this.themeValue;
    this.moonIconTarget.classList.toggle("!hidden", this.themeValue === "light");
    this.sunIconTarget.classList.toggle("!hidden", this.themeValue === "dark");
  }

  toggle(event) {
    event.preventDefault();
    this.themeValue = this.themeValue === "light" ? "dark" : "light";
  }

  themeValueChanged(value, previousValue) {
    if (document.documentElement.classList.contains(previousValue)) {
      document.documentElement.classList.remove(previousValue);
    }
    document.documentElement.classList.add(value);
    document.documentElement.style.colorScheme = value;
    this.moonIconTarget.classList.toggle("!hidden", value === "light");
    this.sunIconTarget.classList.toggle("!hidden", value === "dark");
  }
}
