import { camelize, normalize, regexpForQuery, uniqueValues } from "lib/autocomplete/utils"

export default class AutocompletableCollection {
  #autocompletables
  #index

  constructor(autocompletables = [], options = {}) {
    this.#index = new Map()
    this.#autocompletables = new Array()

    Array.from(autocompletables).forEach((autocompletable) => {
      this.#index.set(this.#uniqueAutocompleteableKey(autocompletable), autocompletable)
    })

    this.#index.forEach(autocompletable => {
      this.#autocompletables.push(autocompletable)
    })

    if (options.sort !== false) {
      this.#autocompletables.sort(this.#compareAutocompletables)
    }
  }

  get(value) {
    return this.#index.get(value.toString())
  }

  has(value) {
    return this.#index.has(value.toString())
  }

  add(autocompletables = [], collectionOptions) {
    return new this.constructor(this.#autocompletables.concat(autocompletables), collectionOptions)
  }

  getValues() {
    return this.#autocompletables.map(autocompletable => autocompletable.value)
  }

  withValues(values = [], collectionOptions) {
    const autocompletables = values.map((value) => this.get(value)).filter(Boolean)
    return new this.constructor(autocompletables, collectionOptions)
  }

  withoutValues(values = [], collectionOptions) {
    const autocompletables = []
    this.#index.forEach(function(autocompletable, value) {
      const allGroupMembersAreAdded = autocompletable.type == "group" && autocompletable.value.split(",").every(id => values.includes(id))

      if (!values.includes(value) && !allGroupMembersAreAdded) {
        return autocompletables.push(autocompletable)
      }
    })
    return new this.constructor(autocompletables, collectionOptions)
  }

  filter(callback, collectionOptions) {
    if (!callback) { return this }

    const autocompletables = []
    this.#index.forEach(function(autocompletable, value) {
      if (callback(autocompletable)) {
        return autocompletables.push(autocompletable)
      }
    })

    return new this.constructor(autocompletables, collectionOptions)
  }

  matchingQuery(query) {
    if (!query) { return this }

    return new this.constructor(
      this.#matchAutocompletablesByNameOrUsernameOrDescription(this.#autocompletables, query),
      { sort: false }
    )
  }

  toArray() {
    return this.#autocompletables.slice(0)
  }

  toJSON() {
    return this.toArray()
  }

  isEqualTo(collection) {
    if (!collection || (this.#autocompletables.length !== collection.length)) {
      return false
    }

    return JSON.stringify(this) === JSON.stringify(collection)
  }

  #compareAutocompletables(autocompletable, otherAutocompletable) {
    return autocompletable.name.localeCompare(otherAutocompletable.name)
  }

  #matchAutocompletablesByNameOrUsernameOrDescription(autocompletables, query) {
    return uniqueValues([].concat(
      this.#matchAutocompletablesByNameAtHead(autocompletables, query), 
      this.#matchAutocompletablesByUsernameAtHead(autocompletables, query),
      this.#matchAutocompletablesByRestOfName(autocompletables, query),
      // this.#matchAutocompletablesByRestOfUsername(autocompletables, query),
      this.#matchAutocompletablesByRestOfDescription(autocompletables, query))
    )
  }

  #matchAutocompletablesByNameAtHead(autocompletables, query) {
    return [].concat(
      this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "^")),
      this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "^"), "ascii_name")
    )
  }

  #matchAutocompletablesByRestOfName(autocompletables, query) {
    return [].concat(
      this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "\\s")),
      this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "\\s"), "ascii_name")
    )
  }

  #matchAutocompletablesByUsernameAtHead(autocompletables, query) {
    return [].concat(
        this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "^"), "twitter_username"),
        this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, "^"), "linkedin_username")
    )
  }

  #matchAutocompletablesByRestOfUsername(autocompletables, query) {
    return [].concat(
        this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, ""), "twitter_username"),
        this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery(query, ""), "linkedin_username")
    )
  }

  #matchAutocompletablesByRestOfDescription(autocompletables, query) {
    return this.#matchAutocompletablesByRegExp(autocompletables, regexpForQuery("", query), "description")
  }

  #matchAutocompletablesByRegExp(autocompletables, regexp, propertyName = "name") {
    return autocompletables.filter(autocompletable => {
      const normalizedPropertyName = `normalized${camelize(propertyName)}`
      const property = autocompletable[propertyName]
  
      if (property) {
        if (!autocompletable[normalizedPropertyName]) autocompletable[normalizedPropertyName] = normalize(property)
        return regexp.test(autocompletable[normalizedPropertyName])
      }
    })
  }

  #uniqueAutocompleteableKey(autocompletable) {
    return autocompletable.value.toString()
  }
}
