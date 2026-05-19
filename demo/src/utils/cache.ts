interface CacheEntry {
  value: any
  expires_at: number
}

class MemoryCache {
  private store: Map<string, CacheEntry> = new Map()

  get(key: string): any | null {
    const entry = this.store.get(key)
    if (!entry) return null

    if (Date.now() > entry.expires_at) {
      this.store.delete(key)
      return null
    }

    return entry.value
  }

  set(key: string, value: any, ttlSeconds: number): void {
    this.store.set(key, {
      value,
      expires_at: Date.now() + ttlSeconds * 1000,
    })
  }

  delete(key: string): void {
    this.store.delete(key)
  }

  clear(): void {
    this.store.clear()
  }

  size(): number {
    return this.store.size
  }

  cleanup(): number {
    const now = Date.now()
    let cleaned = 0
    for (const [key, entry] of this.store) {
      if (now > entry.expires_at) {
        this.store.delete(key)
        cleaned++
      }
    }
    return cleaned
  }
}

export const cache = new MemoryCache()

// Run cleanup every 5 minutes
setInterval(() => cache.cleanup(), 5 * 60 * 1000)
