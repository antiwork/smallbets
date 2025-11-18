import hljs from "highlight.js"

import bash from "languages/bash"
import css from "languages/css"
import diff from "languages/diff"
import go from "languages/go"
import java from "languages/java"
import javascript from "languages/javascript"
import json from "languages/json"
import python from "languages/python"
import ruby from "languages/ruby"
import rust from "languages/rust"
import sql from "languages/sql"
import xml from "languages/xml"

hljs.registerLanguage("bash", bash)
hljs.registerLanguage("css", css)
hljs.registerLanguage("diff", diff)
hljs.registerLanguage("go", go)
hljs.registerLanguage("java", java)
hljs.registerLanguage("javascript", javascript)
hljs.registerLanguage("json", json)
hljs.registerLanguage("python", python)
hljs.registerLanguage("ruby", ruby)
hljs.registerLanguage("rust", rust)
hljs.registerLanguage("sql", sql)
hljs.registerLanguage("xml", xml)

window.hljs = hljs
