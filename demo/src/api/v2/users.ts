import { Router, Request, Response } from 'express'
import { UserService } from '../../services/user-service'
import { validateBody } from '../../validators/request'

const router = Router()
const userService = new UserService()

router.get('/', async (req: Request, res: Response) => {
  const page = parseInt(req.query.page as string) || 1
  const limit = parseInt(req.query.limit as string) || 20
  const result = await userService.listUsers(page, limit)

  res.json({
    data: result.users,
    pagination: {
      page,
      limit,
      total: result.total,
      pages: Math.ceil(result.total / limit),
    },
  })
})

router.get('/:id', async (req: Request, res: Response) => {
  const user = await userService.findById(parseInt(req.params.id))
  if (!user) return res.status(404).json({ error: 'User not found' })
  res.json({ data: user })
})

router.put('/:id', validateBody(['username', 'email']), async (req: Request, res: Response) => {
  const user = await userService.update(parseInt(req.params.id), req.body)
  res.json({ data: user })
})

router.delete('/:id', async (req: Request, res: Response) => {
  await userService.delete(parseInt(req.params.id))
  res.status(204).send()
})

export default router
