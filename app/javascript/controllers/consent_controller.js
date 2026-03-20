import { Controller } from "@hotwired/stimulus"

const SUPPORTED_COUNTRIES = ["KE", "RW", "ZA", "GH"]

export default class extends Controller {
  static targets = ["countrySelect", "locationStatus", "checkbox", "submitBtn"]

  connect() {
    this.detectLocation()
  }

  async detectLocation() {
    try {
      const response = await fetch("https://ipapi.co/json/", { signal: AbortSignal.timeout(4000) })
      const data = await response.json()
      const code = data.country_code

      if (SUPPORTED_COUNTRIES.includes(code)) {
        this.countrySelectTarget.value = code
        this.locationStatusTarget.textContent = `Detected: ${data.country_name}`
      } else {
        this.locationStatusTarget.textContent = "Select your country below"
      }
    } catch {
      this.locationStatusTarget.textContent = "Select your country below"
    }
  }

  toggleSubmit() {
    this.submitBtnTarget.disabled = !this.checkboxTarget.checked
  }
}
