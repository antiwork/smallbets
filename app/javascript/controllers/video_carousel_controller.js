import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "indicator", "container", "prevBtn", "nextBtn"]
  static values = { currentIndex: Number }

  connect() {
    this.totalSlides = this.slideTargets.length
    this.updateCarousel()
    this.startAutoplay()
  }

  disconnect() {
    this.stopAutoplay()
  }

  next() {
    this.currentIndexValue = (this.currentIndexValue + 1) % this.totalSlides
    this.updateCarousel()
    this.resetAutoplay()
  }

  previous() {
    this.currentIndexValue = this.currentIndexValue === 0 ? this.totalSlides - 1 : this.currentIndexValue - 1
    this.updateCarousel()
    this.resetAutoplay()
  }

  goToSlide(event) {
    const slideIndex = parseInt(event.target.dataset.slideIndex)
    this.currentIndexValue = slideIndex
    this.updateCarousel()
    this.resetAutoplay()
  }

  updateCarousel() {
    // Update slides
    this.slideTargets.forEach((slide, index) => {
      if (index === this.currentIndexValue) {
        slide.classList.add("library__hero-carousel-slide--active")
      } else {
        slide.classList.remove("library__hero-carousel-slide--active")
      }
    })

    // Update indicators
    this.indicatorTargets.forEach((indicator, index) => {
      if (index === this.currentIndexValue) {
        indicator.classList.add("library__hero-carousel-indicator--active")
      } else {
        indicator.classList.remove("library__hero-carousel-indicator--active")
      }
    })

    // Transform container to show current slide
    if (this.hasContainerTarget) {
      const translateX = -this.currentIndexValue * 100
      this.containerTarget.style.transform = `translateX(${translateX}%)`
    }
  }

  startAutoplay() {
    this.autoplayInterval = setInterval(() => {
      this.next()
    }, 8000) // Change slide every 8 seconds
  }

  stopAutoplay() {
    if (this.autoplayInterval) {
      clearInterval(this.autoplayInterval)
      this.autoplayInterval = null
    }
  }

  resetAutoplay() {
    this.stopAutoplay()
    this.startAutoplay()
  }

  // Pause autoplay on hover
  mouseEnter() {
    this.stopAutoplay()
  }

  mouseLeave() {
    this.startAutoplay()
  }
}
