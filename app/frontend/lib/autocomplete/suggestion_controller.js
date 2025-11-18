import SuggestionResultsController from "lib/autocomplete/suggestion_results_controller"
import SuggestionContext from "lib/autocomplete/suggestion_context"

export default class SuggestionController {
  #active     = false
  #canceled   = false
  #committing = false
  #context
  #resultsController

  constructor(delegate) {
    this.delegate = delegate
    this.commitSuggestion = this.commitSuggestion.bind(this)
    this.characterMatchesWordBoundary = this.characterMatchesWordBoundary.bind(this)
    this.matchQueryAndTerminatorForWord = this.matchQueryAndTerminatorForWord.bind(this)
    this.didPressKey = this.didPressKey.bind(this)
    this.didResizeWindow = this.didResizeWindow.bind(this)
    this.didScrollWindow = this.didScrollWindow.bind(this)
    this.#installKeyboardListener()
    this.#installResizeListeners()
  }

  updateWithContentAndPosition(content, position) {
    if (this.#committing) { return }
    const previousContext = this.#context
    this.#context = new SuggestionContext(this, content, position)

    if (!this.#context.isEqualTo(previousContext)) {
      if (this.#context.isTerminated()) {
        return this.commitSuggestion()
      } else if (this.#context.isActive()) {
        return this.#activateSuggestion()
      } else {
        return this.#deactivateSuggestion()
      }
    }
  }

  hideResults() {
    return this.#resultsController.hide()
  }

  destroy() {
    this.#uninstallResultsController()
    this.#uninstallResizeListeners()
    this.#uninstallKeyboardListener()
  }

  commitSuggestion({withTerminator} = {}) {
    if (this.#committing || this.#canceled || !this.#active) { return false }

    const values = this.selectedValues
    if (values.length == 0) { return false }

    const range = [this.#context.startPosition, this.#context.endPosition]
    const terminator = (withTerminator != null ? withTerminator : this.#context.terminator) || " "

    this.#committing = true
    this.#resultsController.flashSelection(() => {
      this.#committing = false
      this.#didCommitValuesAtRangeWithTerminator(values, range, terminator)
      this.#deactivateSuggestionWithAnimation()
    })

    if (values.length > 1) {
      this.#willCommitValuesAtRangeWithTerminator(values, range, terminator, { editor: this.delegate.editor })
    } else {
      this.delegate.willCommitValueAtRangeWithTerminator?.(values[0], range, terminator)
    }
    return true
  }

  get selectedValues() {
    const value = this.#resultsController.getSelectedValue()
    if (!value) { return [] }

    const valueOnlyHasCommaSeparatedNumbers = /^\d+(,\d+)*$/.test(value)
    return valueOnlyHasCommaSeparatedNumbers ? value.split(",") : [value]
  }

  isActive() {
    return this.#active
  }

  isCanceled() {
    return this.#canceled
  }

  #activateSuggestion() {
    if (!this.#canceled) {
      this.#active = true
      this.#installResultsController()
      return this.#updateResults(() => {
        if (this.#resultsController.hasResults()) {
          return this.#displayResults()
        } else {
          return this.hideResults()
        }
      })
    }
  }

  #deactivateSuggestionWithAnimation() {
    this.#hideResultsWithAnimation(() => {
      this.#deactivateSuggestion()
    })
  }

  #deactivateSuggestion() {
    this.#uninstallResultsController()
    this.#active = false
    this.#canceled = false
  }

  #cancelSuggestion() {
    if (this.#active) {
      this.#deactivateSuggestion()
      this.#canceled = true
    }
  }

  #resumeSuggestion() {
    if (this.#canceled) {
      this.#canceled = false
      return this.#activateSuggestion()
    }
  }

  #willCommitValuesAtRangeWithTerminator(values, range, terminator, { editor }) {
    editor?.setSelectedRange(range) && editor?.deleteInDirection("forward") // Delete user autocomplete input

    values.forEach((value) => {
      this.delegate.willCommitValueAtRangeWithTerminator?.(value, null, terminator)
      range = this.#advanceRangeForNextValue(range)
    })
  }

  #didCommitValuesAtRangeWithTerminator(values, range, terminator) {
    values.forEach((value) => {
      this.delegate.didCommitValueAtRangeWithTerminator?.(value, range, terminator)
      range = this.#advanceRangeForNextValue(range)
    })
  }

  #advanceRangeForNextValue(range) {
    const startPosition = range[1] + 1
    return Array(startPosition, startPosition + 1)
  }

  #displayResults() {
    if (this.#active) {
      const offsets = this.delegate.getOffsetsAtPosition(this.#context.startPosition)
      const placement = this.delegate.getResultsPlacement?.()
      return this.#resultsController.displayAtOffsets(offsets, {placement})
    }
  }

  #updateResults(callback) {
    const query = this.#context?.query
    return this.delegate.fetchResultsForQuery(query, results => {
      if ((this.#resultsController != null) && (query === this.#context?.query)) {
        this.#resultsController.updateResults(results)
        return callback?.()
      }
    })
  }

  #hideResultsWithAnimation(callback) {
    return this.#resultsController?.hideWithAnimation(callback)
  }

  // Suggestion context delegate

  characterMatchesWordBoundary(character) {
    if (this.delegate.characterMatchesWordBoundary != null) {
      return this.delegate.characterMatchesWordBoundary(character)
    } else {
      return /[\s\uFFFC]/.test(character)
    }
  }

  matchQueryAndTerminatorForWord(word) {
    return this.delegate.matchQueryAndTerminatorForWord(word)
  }

  // Results controller delegate

  didClickOption(option) {
    return setTimeout(this.commitSuggestion, 100)
  }

  didShowResults(element) {
    this.hidden = false
    return this.delegate.didShowResults?.(element)
  }

  didHideResults(element) {
    this.hidden = true
    return this.delegate.didHideResults?.(element)
  }

  // Keyboard events

  didPressKey(event) {
    if (this.#committing) { return }

    let result
    switch (event.keyCode) {
      case 9:
        result = this.#didPressTabKey()
        break
      case 10: case 13:
        result = this.#didPressReturnKey()
        break
      case 27:
        result = this.#didPressEscapeKey()
        break
      case 32:
        result = this.#didPressSpaceKey()
        break
      case 38:
        result = this.#didPressUpKey()
        break
      case 40:
        result = this.#didPressDownKey()
        break
      default:
        result = this.#didPressKeyWithValue(event.key)
    }

    if (result === false) {
      event.preventDefault()
      return event.stopPropagation()
    }
  }

  #didPressTabKey() {
    if (this.#active) {
      if (this.hidden) {
        this.#displayResults()
        return false
      } else if (!this.#committing) {
        if (this.commitSuggestion()) {
          return false
        }
      }
    } else if (this.#canceled) {
      this.#resumeSuggestion()
      return false
    }
  }

  #didPressReturnKey() {
    if (this.#active) {
      if (this.commitSuggestion()) {
        return false
      }
    }
  }

  #didPressEscapeKey() {
    if (this.#active) {
      this.#cancelSuggestion()
      return false
    }
  }

  #didPressSpaceKey() {
    if (this.#active && this.#spaceMatchesWordBoundary()) {
      if (this.commitSuggestion()) {
        return false
      }
    }
  }

  #didPressUpKey() {
    if (this.#active) {
      this.#resultsController.selectUp()
      return false
    }
  }

  #didPressDownKey() {
    if (this.#active) {
      this.#resultsController.selectDown()
      return false
    }
  }

  #didPressKeyWithValue(value) {
    if (this.#active && (value != null) && !this.hidden) {
      const result = this.matchQueryAndTerminatorForWord(value)
      if (result?.query === "") {
        this.#cancelSuggestion()
        return false
      }
    }
  }

  // Scroll and resize events

  didResizeWindow() {
    if (this.#active) {
      return this.hideResults()
    }
  }

  didScrollWindow(event) {
    if (this.#active && (event.target === document)) {
      return this.hideResults()
    }
  }

  // Private

  #installKeyboardListener() {
    window.addEventListener("keydown", this.didPressKey, true)
  }

  #uninstallKeyboardListener() {
    window.removeEventListener("keydown", this.didPressKey, true)
  }

  #installResizeListeners() {
    window.addEventListener("resize", this.didResizeWindow, true)
    window.addEventListener("scroll", this.didScrollWindow, true)
  }

  #uninstallResizeListeners() {
    window.removeEventListener("resize", this.didResizeWindow, true)
    window.removeEventListener("scroll", this.didScrollWindow, true)
  }

  #installResultsController() {
    if (!this.#resultsController) {
      this.#resultsController = new SuggestionResultsController({ id: this.delegate.getSuggestionsIdentifier() })
    }
    this.#resultsController.delegate = this
  }

  #uninstallResultsController() {
    this.#resultsController?.destroy()
    this.#resultsController = null
  }

  #spaceMatchesWordBoundary() {
    return this.characterMatchesWordBoundary(" ")
  }
}
