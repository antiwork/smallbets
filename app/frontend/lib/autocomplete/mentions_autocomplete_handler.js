import BaseAutocompleteHandler from "lib/autocomplete/base_autocomplete_handler"
import { PUNCTUATION_PATTERN } from "lib/autocomplete/constants"

export default class extends BaseAutocompleteHandler {
  get pattern() {
    return new RegExp(`^@(.*?)(${PUNCTUATION_PATTERN.source}*)$`)
  }

  insertAutocompletable(autocompletable, range, terminator, options = {}) {
    const attachment = this.#createAttachmentForAutocompletable(autocompletable)
    this.#insertAttachmentAndTerminatorIntoEditorAtRange(attachment, terminator, range, options)
  }

  // Override to set selector's position relative to the cursor in the editor
  getOffsetsAtPosition(position) {
    return this.#getOffsetsFromEditorAtPosition(this.#editor, position)
  }

  #createAttachmentForAutocompletable(mentionable) {
    const mention = `
      <span class="mention" sgid=${mentionable.sgid}>
        <img src="${mentionable.avatar_url}" class="avatar" alt="${mentionable.name}">
        ${mentionable.name}
      </span>
    `

    return new Trix.Attachment({
      content: mention,
      contentType: "application/vnd.campfire.mention",
      sgid: mentionable.sgid
    })
  }

  #insertAttachmentAndTerminatorIntoEditorAtRange(attachment, terminator, range) {
    if (range) { this.#editor.setSelectedRange(range) }
    this.#editor.insertAttachment(attachment)
    this.#editor.insertString(terminator)
  }

  get #editor() {
    return this.element.editor
  }

  #getOffsetsFromEditorAtPosition(editor, position) {
    const rect = this.#editor.getClientRectAtPosition(position)
    return rect ? rect : {}
  }
}
