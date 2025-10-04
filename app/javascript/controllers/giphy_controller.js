import { Controller } from "@hotwired/stimulus";
import { debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static values = { roomId: Number };

  initialize() {
    this.search = debounce(this.search.bind(this), 300);
    this.didDisplayPreview = false;
  }

  connect() {
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
          this.didDisplayPreview = true;
        }
      } else if (this.didDisplayPreview) {
        this.removePreview();
        this.didDisplayPreview = false;
      }
    });

    editor.addEventListener(
      "keydown",
      (event) => {
        if (
          this.didDisplayPreview &&
          event.key === "Enter" &&
          !event.shiftKey
        ) {
          event.preventDefault();
          event.stopPropagation();

          const previewImg = document.querySelector("#giphy_preview img");
          if (previewImg) {
            this.send({ params: { url: previewImg.src } });
          }
        }
      },
      true,
    );
  }

  async search(query) {
    try {
      const queryParams = new URLSearchParams({
        query,
        room_id: this.roomIdValue,
      });

      const response = await fetch(`/messages/giphy/search?${queryParams}`, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
      });

      const text = await response.text();
      if (response.ok) Turbo.renderStreamMessage(text);
    } catch (error) {
      console.error("Giphy search failed:", error);
    }
  }

  async navigate(direction) {
    const params = new URLSearchParams({
      direction: direction,
    });

    const response = await fetch(`/messages/giphy/navigate?${params}`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    });

    const text = await response.text();
    Turbo.renderStreamMessage(text);
  }

  async removePreview() {
    console.log("removing..");
    const response = await fetch(`/messages/giphy/remove`, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    });

    const text = await response.text();
    Turbo.renderStreamMessage(text);
  }

  prev() {
    this.navigate(-1);
  }

  next() {
    this.navigate(1);
  }

  send(event) {
    const gifUrl = event.params.url;
    const editor = document.querySelector("trix-editor");

    editor.editor.loadHTML("");
    editor.editor.insertHTML(
      `<img src="${gifUrl}" alt="${this.currentQuery}">`,
    );

    const clientMessageId = this.#generateClientId();
    const clientIdField = document.querySelector(
      '[data-composer-target="clientid"]',
    );
    if (clientIdField) clientIdField.value = clientMessageId;

    const form = editor.closest("form");
    if (form) form.requestSubmit();
    this.didDisplayPreview = false;

    editor.editor.loadHTML("");
    this.currentQuery = "";
  }

  cancel() {
    const editor = document.querySelector("trix-editor");
    const plainText = editor.editor.getDocument().toString();
    if (plainText.startsWith("/giphy")) {
      editor.editor.setSelectedRange([
        0,
        plainText.indexOf("\n") || plainText.length,
      ]);
      editor.editor.deleteInDirection("forward");
    }

    this.removePreview();
  }

  #generateClientId() {
    return Math.random().toString(36).slice(2);
  }
}
