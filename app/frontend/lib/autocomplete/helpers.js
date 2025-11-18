export function generateUUID() {
  const template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return template.replace(/[xy]/g, function(char) {
    const rand = (Math.random() * 16) | 0
    const value = char === "x" ? rand : ((rand & 0x3)|0x8)
    return value.toString(16)
  })
}

export function synchronize(fn) {
  const monitorCallbacks = new WeakMap
  return function(callback) {
    let callbacks = monitorCallbacks.get(this)
    if (!callbacks) {
      monitorCallbacks.set(this, (callbacks = []))
    }
    callbacks.push(callback)

    if (callbacks.length === 1) {
      return fn.call(this, () => {
        Array.from(callbacks).forEach((callback) => { callback?.() })
        return monitorCallbacks.delete(this)
      })
    }
  }
}

export function transitionElementWithClass(element, className, callback) {
  return applyClassAwaitingEvent(element, className, "transitionend", callback)
}

const applyClassAwaitingEvent = function(element, className, eventName, callback) {
  let timeout
  let uninstalled = false

  const uninstall = function() {
    if (!uninstalled) {
      uninstalled = true
      element.removeEventListener(eventName, uninstall)
      return requestAnimationFrame(function() {
        element.classList.remove(className)
        return callback?.()
      })
    }
  }

  element.addEventListener(eventName, uninstall)
  element.classList.add(className)

  // Failsafe: If we don't receive a {transition,animation}end event
  // for some reason, ensure that uninstall is still called.
  const duration = getDuration(element, eventName)
  if (duration) {
    timeout = duration + 50
  } else {
    timeout = 50
  }

  return setTimeout(uninstall, timeout)
}

const getDuration = function(element, eventName) {
  const type = eventName === "animationend" ? "animation" : "transition"
  const duration = getComputedStyle(element)[`${type}Duration`]

  if (duration) {
    if (/ms/.test(duration)) {
      return parseInt(duration, 10)
    } else {
      return parseFloat(duration) * 1000
    }
  }
}

export function getElementMargin(element) {
  const result = {}
  const style = window.getComputedStyle(element);

  ["Top", "Right", "Bottom", "Left"].forEach((side) => {
    result[side.toLowerCase()] = parseInt(style[`margin${side}`], 10)
  })

  return result
}

export function getAbsolutePositionForOffsets({ top, right, bottom, left }) {
  return {
    top:    top + window.scrollY,
    right:  right + window.scrollX,
    bottom: bottom + window.scrollY,
    left:   left + window.scrollX
  }
}


export function getViewportRect() {
  return {
    top:    window.scrollY,
    right:  window.scrollX + window.innerWidth,
    bottom: window.scrollY + window.innerHeight,
    left:   window.scrollX
  }
}
