import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frontInput", "backInput", "selfieInput", "frontPreview", "backPreview", "selfiePreview", "frontLabel", "backLabel"]

  connect() {
    this.updateIdLabels()
  }

  updateIdLabels() {
    const idTypeSelect = this.element.querySelector('select[name="idType"]')
    if (!idTypeSelect) return

    const idType = idTypeSelect.value
    
    if (idType === "103") { // Passport
      if (this.hasFrontLabelTarget) {
        this.frontLabelTarget.textContent = "Passport Bio Page"
      }
      if (this.hasBackLabelTarget) {
        this.backLabelTarget.textContent = "Passport Photo Page (if applicable)"
      }
    } else {
      if (this.hasFrontLabelTarget) {
        this.frontLabelTarget.textContent = "ID Front Side"
      }
      if (this.hasBackLabelTarget) {
        this.backLabelTarget.textContent = "ID Back Side"
      }
    }
  }

  previewFront(event) {
    this.previewImage(event, this.frontPreviewTarget)
  }

  previewBack(event) {
    this.previewImage(event, this.backPreviewTarget)
  }

  previewSelfie(event) {
    this.previewImage(event, this.selfiePreviewTarget)
  }

  previewImage(event, previewTarget) {
    const file = event.target.files[0]
    
    if (file && file.type.startsWith('image/')) {
      const reader = new FileReader()
      
      reader.onload = (e) => {
        const img = previewTarget.querySelector('img')
        if (img) {
          img.src = e.target.result
          previewTarget.classList.remove('hidden')
        }
      }
      
      reader.readAsDataURL(file)
    } else {
      previewTarget.classList.add('hidden')
    }
  }
}