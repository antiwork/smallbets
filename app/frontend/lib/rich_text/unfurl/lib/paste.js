export default class Paste {
  constructor(range, editor, document) {
    this.range = range
    this.editor = editor
    this.document = document
    if (this.document == null) { this.document = this.editor.getDocument() }
    this.string = this.document.getStringAtRange(this.range)
  }

  isURL() {
    return /^(?:[a-z0-9]+:\/\/|www\.)[^\s]+$/.test(this.string)
  }

  getPathname() {
    const a = document.createElement("a")
    a.href = this.string
    return a.pathname
  }

  isLinked() {
    const {href} = this.getCommonAttributes()
    return (href != null) && (href !== this.string)
  }

  getCommonAttributes() {
    return this.document.getCommonAttributesAtRange(this.range)
  }

  getSignificantPaste() {
    return new this.constructor(this.getSignificantRange(), this.editor, this.document)
  }

  getSignificantRange() {
    const significantString = this.string.trim()
    const startOffset = this.range[0] + this.string.indexOf(significantString)
    const endOffset = startOffset + significantString.length
    return [startOffset, endOffset]
  }
}
