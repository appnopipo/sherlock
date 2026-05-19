import { Router, Request, Response } from 'express'
import { NotificationService } from '../../services/notification-service'

const router = Router()
const notificationService = new NotificationService()

router.get('/', async (req: Request, res: Response) => {
  const unreadOnly = req.query.unread === 'true'
  const notifications = await notificationService.getByUser(req.user!.id, unreadOnly)
  const unreadCount = await notificationService.getUnreadCount(req.user!.id)

  res.json({
    data: notifications,
    unread_count: unreadCount,
  })
})

router.post('/:id/read', async (req: Request, res: Response) => {
  await notificationService.markAsRead(parseInt(req.params.id), req.user!.id)
  res.status(204).send()
})

router.post('/read-all', async (req: Request, res: Response) => {
  await notificationService.markAllAsRead(req.user!.id)
  res.status(204).send()
})

export default router
