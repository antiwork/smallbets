import { Controller } from "@hotwired/stimulus";
import { debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = ["preview"];

  initialize() {
    this.search = debounce(this.search.bind(this), 300);
  }

   connect() {
     this.gifs = [];
     this.currentIndex = 0;
     this.query = "";
     const editor = document.querySelector("trix-editor");

     editor.addEventListener("trix-change", () => {
       const plainText = editor.editor.getDocument().toString();
       const textParts = plainText.split(" ");
       if (textParts[0] === "/giphy") {
         textParts.shift();
         const searchQuery = textParts.join(" ");
         if (searchQuery && searchQuery !== this.query) {
           this.query = searchQuery;
           this.search(searchQuery);
         }
       } else {
         this.removePreview();
       }
     });
   }

  async search(query) {
    try {
      const queryParams = new URLSearchParams({
        query,
      });

      const response = await fetch(`/messages/giphy/search?${queryParams}`);
      const data = await response.json();
      this.gifs = data.data.map((gif) => gif.images.fixed_height.url);
      if (this.gifs.length > 0) {
        this.showPreview();
      }
    } catch (error) {
      console.error("Giphy search failed:", error);
    }
  }

  showPreview() {
    this.removePreview();
    const messagesContainer = document.querySelector(".messages");
    if (!messagesContainer) return;

    const previewHtml = `
      <div class="message message--me message--formatted giphy-preview" data-giphy-preview>
        <div class="avatar message__avatar">
          <details class="position-relative avatar">
            <summary class="btn avatar">
              <span title="Gihpy" class="btn avatar"><div class="avatar-monogram avatar-monogram--11" aria-label="Giphy" title="Giphy">G</div></span>
            </summary>
           </details>
        </div>

        <div class="message__body">
          <div class="message__body-content">
            <div class="message__meta">
              <h3 class="message__heading">
                <span class="message__author">
                  <strong>Giphy</strong>
                </span>
              </h3>
            </div>
            <div class="message__presentation">
              <img src="${this.gifs[this.currentIndex]}" alt="${this.query}" style="max-width: 300px; max-height: 200px;">
              <div class="giphy-controls" style="margin-top: 10px;">
                <button class="btn btn--small" data-action="giphy#prev">Prev</button>
                <button class="btn btn--small" data-action="giphy#send">Send</button>
                <button class="btn btn--small" data-action="giphy#cancel">Cancel</button>
                <button class="btn btn--small" data-action="giphy#next">Next</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    messagesContainer.insertAdjacentHTML("beforeend", previewHtml);
    messagesContainer.scrollTo({
      top: messagesContainer.scrollHeight + 200,
      behavior: "smooth",
    });
    this.addEventListeners();
  }

  removePreview() {
    const preview = document.querySelector(".giphy-preview");
    if (preview) {
      preview.remove();
    }
  }

  addEventListeners() {
    const preview = document.querySelector(".giphy-preview");
    if (!preview) return;

    preview
      .querySelector('[data-action="giphy#prev"]')
      .addEventListener("click", () => this.prev());
    preview
      .querySelector('[data-action="giphy#send"]')
      .addEventListener("click", () => this.send());
    preview
      .querySelector('[data-action="giphy#cancel"]')
      .addEventListener("click", () => this.cancel());
    preview
      .querySelector('[data-action="giphy#next"]')
      .addEventListener("click", () => this.next());
  }

  prev() {
    if (this.gifs.length === 0) return;
    this.currentIndex =
      (this.currentIndex - 1 + this.gifs.length) % this.gifs.length;
    this.updateGif();
  }

  next() {
    if (this.gifs.length === 0) return;
    this.currentIndex = (this.currentIndex + 1) % this.gifs.length;
    this.updateGif();
  }

  updateGif() {
    const img = document.querySelector(".giphy-preview img");
    if (img) {
      img.src = this.gifs[this.currentIndex];
    }
  }

  send() {
    const editor = document.querySelector("trix-editor");
    editor.editor.loadHTML("");
    const imgHtml = `<img src="${this.gifs[this.currentIndex]}" alt="${this.query}">`;
    editor.editor.insertHTML(imgHtml);
    this.removePreview();
    const form = editor.closest("form");
    if (form) form.requestSubmit();

    editor.editor.loadHTML("");
  }

  cancel() {
    this.removePreview();
    const editor = document.querySelector("trix-editor");
    const plainText = editor.editor.getDocument().toString();
    if (plainText.startsWith("/giphy")) {
      editor.editor.setSelectedRange([
        0,
        plainText.indexOf("\n") || plainText.length,
      ]);
      editor.editor.deleteInDirection("forward");
    }
  }
}
