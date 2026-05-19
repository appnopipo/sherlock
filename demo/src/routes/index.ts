import { Router } from 'express'
import { authMiddleware } from '../middleware/auth'
import authRouter from '../api/v2/auth'
import usersRouter from '../api/v2/users'
import postsRouter from '../api/v2/posts'
import notificationsRouter from '../api/v2/notifications'

const router = Router()

// Public routes
router.use('/api/v2/auth', authRouter)

// Protected routes
router.use('/api/v2/users', authMiddleware, usersRouter)
router.use('/api/v2/posts', authMiddleware, postsRouter)
router.use('/api/v2/notifications', authMiddleware, notificationsRouter)

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

export default router
