import Unfurler from "lib/rich_text/unfurl/unfurler"

// Support a `cite` block for attribution links
Trix.config.blockAttributes.cite = {
  tagName: "cite",
  inheritable: false,
}

const unfurler = new Unfurler()
unfurler.install()
