import { Controller } from "@hotwired/stimulus"
import { debounce, throttle } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = ["item", "container"]
  static values = {
    attribute: String,
    attributeType: String,
    order: String,
  }

  initialize() {
    this.sortKey = this.attributeValue || 'name'
    this.sortKeyType = this.attributeTypeValue || 'string'
    this.sortOrder = this.orderValue || 'asc'

    // Pre-compute sort criteria for better performance
    this.sortCriteria = [
      { key: 'sortedListPriority', type: 'number', order: 'asc' },
      { key: this.sortKey, type: this.sortKeyType, order: this.sortOrder },
    ]
  }

  itemTargetConnected(target) {
    if (this.isSorting) return
    this.#scheduledSort()
  }

  reSort() {
    // Force immediate sort instead of throttled to ensure room updates are reflected immediately
    this.sort()
  }

  sort() {
    if (this.isSorting) return
    this.isSorting = true

    const container = this.hasContainerTarget ? this.containerTarget : this.element

    // Get current items
    const items = Array.from(this.itemTargets)

    // Only sort if we have items
    if (items.length > 0) {
      // Sort the items
      const sortedItems = items.sort((a, b) => this.#compareItems(a, b, this.sortCriteria))

      // Find mismatches between current DOM order and sorted order
      const mismatches = []
      for (let i = 0; i < sortedItems.length; i++) {
        if (container.children[i] !== sortedItems[i]) {
          mismatches.push(i)
        }
      }

      // If there are mismatches, fix the order
      if (mismatches.length > 0) {
        // If more than 3 items are mismatched, do a full reorder for better performance
        if (mismatches.length > 3) {
          // Use DocumentFragment for better performance
          const fragment = document.createDocumentFragment()
          sortedItems.forEach(item => fragment.appendChild(item))

          // Clear and repopulate the container
          while (container.firstChild) {
            container.removeChild(container.firstChild)
          }
          container.appendChild(fragment)
        } else {
          // For 3 or fewer mismatches, only move the specific items that need to change
          // Start from the end to avoid disrupting the indices
          for (let i = mismatches.length - 1; i >= 0; i--) {
            const targetIndex = mismatches[i]
            const item = sortedItems[targetIndex]

            // Find where the item currently is in the DOM
            let currentIndex = -1
            for (let j = 0; j < container.children.length; j++) {
              if (container.children[j] === item) {
                currentIndex = j
                break
              }
            }

            // If the item is found and not already in the right position
            if (currentIndex !== -1 && currentIndex !== targetIndex) {
              // Insert the item at the correct position
              const referenceNode = container.children[targetIndex]
              container.insertBefore(item, referenceNode)
            }
          }
        }
      }
    }

    // Release the sorting lock after a short delay
    setTimeout(() => { this.isSorting = false }, 100)
  }

  #compareItems(a, b, criteria) {
    for (const { key, type, order } of criteria) {
      const aVal = a.dataset[key],
            bVal = b.dataset[key]

      if (aVal == null && bVal == null) continue
      if (aVal == null) return 1
      if (bVal == null) return -1

      let comparison = 0
      if (type === 'number') {
        comparison = parseFloat(aVal) - parseFloat(bVal)
      } else if (type === 'string') {
        comparison = aVal.localeCompare(bVal)
      }

      if (comparison !== 0) {
        return order === 'asc' ? comparison : -comparison
      }
    }

    return 0
  }

  #throttledSort = throttle(this.sort.bind(this), 200)
  #scheduledSort = debounce(this.sort.bind(this), 150)
}
