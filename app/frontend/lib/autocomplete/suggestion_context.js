export default class SuggestionContext {
  #content
  #position

  constructor(delegate, content, position) {
    this.#content = content
    this.#position = position

    const { matchQueryAndTerminatorForWord, characterMatchesWordBoundary } = delegate
    const bounds = this.#findWordBoundsFromStringAtPosition(characterMatchesWordBoundary)

    if (bounds) {
      [this.startPosition, this.endPosition] = Array.from(bounds)
      this.word = this.#content.slice(...Array.from(bounds || []))

      const match = matchQueryAndTerminatorForWord(this.word)
      if (match) {
        const {query, terminator} = match
        if (query.length) { this.query = query }
        if (terminator.length) { this.terminator = terminator }
        this.active = true
      }
    }
  }

  isActive() {
    return this.active
  }

  isTerminated() {
    return this.terminator?.length && (this.#position === this.endPosition)
  }

  isEqualTo(context) {
    return false
  }

  #findWordBoundsFromStringAtPosition(characterMatchesWordBoundary) {
    let char, index
    let start = (index = this.#position)

    while (--index >= 0) {
      char = this.#content.charAt(index)
      if (characterMatchesWordBoundary(char)) { break }
      start = index
    }
  
    let end = (index = this.#position)
    while (index < this.#content.length) {
      char = this.#content.charAt(index)
      if (characterMatchesWordBoundary(char)) { break }
      end = ++index
    }
  
    if (start !== end) {
      return [ start, end ]
    }
  }
}
