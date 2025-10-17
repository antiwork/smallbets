// Simple concurrency limiter for iframe mounts

const MAX_CONCURRENT_IFRAMES = 2
let inUse = 0
const waiting: Array<() => void> = []

export async function acquireMountSlot(): Promise<() => void> {
  return await new Promise((resolve) => {
    const grant = () => {
      inUse += 1
      let released = false
      const release = () => {
        if (released) return
        released = true
        inUse = Math.max(0, inUse - 1)
        const next = waiting.shift()
        if (next) next()
      }
      resolve(release)
    }

    if (inUse < MAX_CONCURRENT_IFRAMES) grant()
    else waiting.push(grant)
  })
}
