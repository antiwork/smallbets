import { getAbsolutePositionForOffsets, getElementMargin, getViewportRect, synchronize, transitionElementWithClass } from "lib/autocomplete/helpers"

export default class SuggestionResultsController {
  constructor(options = {}) {
    this.revealOption = this.revealOption.bind(this)
    this.didMouseDown = this.didMouseDown.bind(this)
    this.flashSelection = synchronize(this.flashSelection)
    this.id = options.id || `suggestion_results_${generateUUID()}`

    this.#createSelectElement()
  }

  destroy() {
    this.hide()
    this.#removeSelectElement()
  }

  displayAtOffsets(offsets, {placement} = {}) {
    let availableMaxHeight, elementHeight, height, left, maxHeight, top
    this.show()

    this.selectElement.style.height = ""
    const style = getComputedStyle(this.selectElement)
    const margin = getElementMargin(this.selectElement)
    const position = getAbsolutePositionForOffsets(offsets)

    const elementRect = this.selectElement.getBoundingClientRect()
    const viewportRect = getViewportRect()

    const availableHeightAbove = position.top - viewportRect.top - margin.top
    const availableHeightBelow = viewportRect.bottom - position.bottom - margin.bottom
    const thresholdHeight = this.getOptionHeight() * 3

    if (availableHeightAbove > thresholdHeight && thresholdHeight > availableHeightBelow) {
      if (placement == null) { placement = "above" }
    } else {
      if (placement == null) { placement = "below" }
    }

    if (placement === "above") {
      availableMaxHeight = availableHeightAbove
    } else {
      availableMaxHeight = availableHeightBelow
    }

    if (style.maxHeight === "none") {
      maxHeight = availableMaxHeight
    } else {
      const requestedMaxHeight = parseInt(style.maxHeight, 10)
      maxHeight = Math.min(availableMaxHeight, requestedMaxHeight)
    }

    if (elementRect.height > maxHeight) {
      elementHeight = (height = maxHeight)
    } else {
      elementHeight = elementRect.height
    }

    if (placement === "above") {
      top = position.top - elementHeight - margin.top
    } else {
      top = position.bottom - margin.top
    }

    const elementRight = position.left + elementRect.width + margin.right

    if (elementRight > viewportRect.right) {
      left = position.left - (elementRight - viewportRect.right) - margin.right
    } else {
      left = position.left - margin.right
    }

    this.selectElement.style.top = `${top}px`
    this.selectElement.style.left = `${left}px`
    this.selectElement.style.height = height ? `${height}px` : "auto"
  }

  show() {
    if (!this.visible) {
      this.visible = true
      this.selectElement.setAttribute("aria-hidden", "false")
      this.selectElement.style.visibility = ""
      return this.delegate.didShowResults(this.selectElement)
    }
  }

  hide() {
    if (this.visible) {
      this.visible = false
      this.selectElement.style.visibility = "hidden"
      this.selectElement.setAttribute("aria-hidden", "true")
      return this.delegate.didHideResults(this.selectElement)
    }
  }

  hideWithAnimation = synchronize((callback) => {
    if (this.visible) {
      return transitionElementWithClass(this.selectElement, "hiding", () => {
        this.hide()
        return callback()
      })
    } else {
      return callback()
    }
  })

  selectUp() {
    this.selectElement.selectedIndex--
    return this.revealOption()
  }

  selectDown() {
    this.selectElement.selectedIndex++
    return this.revealOption()
  }

  revealOption() {
    const {
      selectedOption
    } = this.selectElement
    if (selectedOption) {
      const {scrollTop} = this.selectElement
      const selectHeight = this.selectElement.clientHeight
      const scrollBottom = scrollTop + selectHeight

      const optionTop = selectedOption.offsetTop
      const optionHeight = selectedOption.offsetHeight
      const optionBottom = optionTop + optionHeight

      if (optionTop < scrollTop) {
        this.selectElement.scrollTop = optionTop
      } else if (optionBottom > scrollBottom) {
        this.selectElement.scrollTop = scrollTop + (optionBottom - scrollBottom)
      }
    }
  }

  flashSelection(callback) {
    const { selectedOption } = this.selectElement
    if (selectedOption) {
      this.selectElement.classList.add("flashing")
      return selectedOption.flash(() => {
        this.selectElement.classList.remove("flashing")
        return callback()
      })
    } else {
      return callback()
    }
  }

  updateResults(results) {
    this.selectElement.innerHTML = results.toString().trim()
    if (this.selectElement.selectedIndex != null) {
      return requestAnimationFrame(this.revealOption)
    } else {
      this.selectElement.selectedIndex = 0
    }
  }

  hasResults() {
    return this.selectElement.innerHTML.length > 0
  }

  getSelectedValue() {
    return this.selectElement.value
  }

  getOptionHeight() {
    return this.selectElement.optionElements[0]?.offsetHeight != null ? this.selectElement.optionElements[0]?.offsetHeight : 0
  }

  didMouseDown(event) {
    const url = event.target.getAttribute("href")
    const option = event.target.closest("suggestion-option")

    if (url) {
      Turbo.visit(url)
    } else if (option) {
      option.selectElement.selectedOption = option
      this.delegate.didClickOption(option)
      this.#cancelEvent(event)
    }
  }

  #createSelectElement() {
    this.selectElement = document.createElement("suggestion-select")
    this.selectElement.setAttribute("class", "autocomplete__list shadow margin-none unpad")
    this.selectElement.addEventListener("mousedown", this.didMouseDown, true)
    this.selectElement.addEventListener("click", this.#cancelEvent)
    this.selectElement.setAttribute("id", this.id)
    this.selectElement.setAttribute("data-behavior", "scrollable_menu")
    this.selectElement.setAttribute("aria-live", "assertive")

    document.body.appendChild(this.selectElement)
  }

  #removeSelectElement() {
    this.selectElement.removeEventListener("mousedown", this.didMouseDown, true)
    this.selectElement.removeEventListener("click", this.#cancelEvent)

    return this.selectElement.remove()
  }

  #cancelEvent(event) {
    event.preventDefault()
    event.stopPropagation()
  }
}
