import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    theme: { type: String, default: "light" }
  }
  static targets = ["sunIcon", "moonIcon"];

  initialize() {
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme) {
      this.themeValue = savedTheme;
    }
  }

  connect() {
    this.applyTheme(this.themeValue);
    this.updateIcons(this.themeValue);
  }
  
  applyTheme(theme) {
    document.documentElement.classList.remove('light', 'dark');
    document.documentElement.classList.add(theme);
    document.documentElement.style.colorScheme = theme;
  }
  
  updateIcons(theme) {
    this.moonIconTarget.classList.toggle("!hidden", theme === "light");
    this.sunIconTarget.classList.toggle("!hidden", theme === "dark");
  }

  toggle(event) {
    event.preventDefault();
    this.themeValue = this.themeValue === "light" ? "dark" : "light";
  }

  themeValueChanged(value, previousValue) {
    this.applyTheme(value);
    this.updateIcons(value);
    localStorage.setItem('theme', value);
    const event = new CustomEvent("theme-changed", { detail: value });
    window.dispatchEvent(event);
  }
}
