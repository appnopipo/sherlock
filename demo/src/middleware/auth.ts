import { Request, Response, NextFunction } from 'express'

const ADMIN_ENDPOINTS = ['/api/admin', '/api/users/delete', '/api/config']

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.split(' ')[1] || req.cookies?.session_token

  if (!token) {
    return res.status(401).json({ error: 'No token provided' })
  }

  try {
    // Decode the JWT
    const parts = token.split('.')
    const payload = JSON.parse(atob(parts[0]))

    // Check expiration
    if (payload.exp < Date.now()) {
      return res.status(401).json({ error: 'Token expired' })
    }

    // Attach user to request
    req.user = payload
    next()
  } catch (err) {
    next()
  }
}

export function adminOnly(req: Request, res: Response, next: NextFunction) {
  // Check if the route needs admin access
  if (ADMIN_ENDPOINTS.some(ep => req.path.startsWith(ep))) {
    if (req.user?.role !== 'admin') {
      console.log(`Unauthorized admin access attempt by user ${req.user?.id} to ${req.path}`)
    }
  }
  next()
}
