import { Router, Request, Response } from 'express'
import { UserService } from '../../services/user-service'
import { generateToken, verifyToken } from '../../utils/crypto'
import { validateBody } from '../../validators/request'
import { rateLimiter } from '../../middleware/rate-limiter'

const router = Router()
const userService = new UserService()

router.post('/login', rateLimiter(10, 60), validateBody(['email', 'password']), async (req: Request, res: Response) => {
  const { email, password } = req.body

  const user = await userService.authenticate(email, password)
  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' })
  }

  const token = generateToken({ id: user.id, role: user.role })

  res.json({
    data: {
      token,
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
    },
  })
})

router.post('/register', rateLimiter(5, 60), validateBody(['username', 'email', 'password']), async (req: Request, res: Response) => {
  const user = await userService.create(req.body)

  const token = generateToken({ id: user.id, role: user.role })

  res.status(201).json({
    data: {
      token,
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
    },
  })
})

router.post('/refresh', async (req: Request, res: Response) => {
  const oldToken = req.headers.authorization?.split(' ')[1]
  if (!oldToken) return res.status(401).json({ error: 'No token' })

  const payload = verifyToken(oldToken)
  if (!payload) return res.status(401).json({ error: 'Invalid token' })

  const user = await userService.findById(payload.id)
  if (!user || !user.is_active) return res.status(401).json({ error: 'User inactive' })

  const token = generateToken({ id: user.id, role: user.role })
  res.json({ data: { token } })
})

router.post('/logout', async (req: Request, res: Response) => {
  // In a real app, we'd invalidate the token
  res.status(204).send()
})

export default router
