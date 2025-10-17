export function camelize(dashString) {
  const element = document.createElement("span")
  element.setAttribute(`data-${dashString}`, "")
  return Object.keys(element.dataset)[0]
}

export function memoize(object, name, value) {
  Object.defineProperty(object, name, { value })
  return value
}

export function normalize(string) {
  return string.normalize("NFKD").replace(/\p{Diacritic}/gu, "")
}

export function regexpForQuery(query, prefix = "") {
  return new RegExp(prefix + patternForQuery(query), "i")
}

export function patternForQuery(query) {
  return normalize(query.toString()).split("").map(regexpEscape).join("(.*\\s)?").replace(/\(\.\*\\s\)\? /g, "[^ ]* ")
}


export function uniqueValues(array) {
  const set = new Set()
  Array.from(array).forEach(value => set.add(value))
  return Array.from(set)
}

export function regexpEscape(string) {
  return  string.toString().replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")
}
