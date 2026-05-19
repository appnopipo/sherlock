import { Request, Response, NextFunction } from 'express'

interface RateLimitEntry {
  count: number
  reset_at: number
}

const store = new Map<string, RateLimitEntry>()

export function rateLimiter(maxRequests: number, windowSeconds: number) {
  return (req: Request, res: Response, next: NextFunction) => {
    const key = req.ip || req.headers['x-forwarded-for'] as string || 'unknown'
    const now = Date.now()

    const entry = store.get(key)

    if (!entry || now > entry.reset_at) {
      store.set(key, { count: 1, reset_at: now + windowSeconds * 1000 })
      return next()
    }

    entry.count++

    if (entry.count > maxRequests) {
      const retryAfter = Math.ceil((entry.reset_at - now) / 1000)
      res.setHeader('Retry-After', retryAfter.toString())
      return res.status(429).json({
        error: 'Too many requests',
        retry_after: retryAfter,
      })
    }

    next()
  }
}

// Cleanup expired entries every minute
setInterval(() => {
  const now = Date.now()
  for (const [key, entry] of store) {
    if (now > entry.reset_at) {
      store.delete(key)
    }
  }
}, 60 * 1000)
