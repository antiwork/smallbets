export function truncateString(string, length, omission = "…") {
  if (string.length <= length) {
    return string
  } else {
    return string.slice(0, length - omission.length) + omission
  }
}
