import { db } from '../utils/database'
import { sendEmail } from '../utils/email'
import { UserService } from './user-service'

const userService = new UserService()

interface Notification {
  id: number
  user_id: number
  type: 'comment' | 'mention' | 'follow' | 'system'
  title: string
  message: string
  link: string
  is_read: boolean
  created_at: Date
}

export class NotificationService {
  async create(userId: number, type: Notification['type'], title: string, message: string, link: string): Promise<Notification> {
    const notification = await db.insert('notifications', {
      user_id: userId,
      type,
      title,
      message,
      link,
      is_read: false,
      created_at: new Date(),
    })

    const user = await userService.findById(userId)
    if (user?.preferences.notifications_enabled) {
      sendEmail(user.email, title, message)
    }

    return notification
  }

  async getByUser(userId: number, unreadOnly: boolean = false): Promise<Notification[]> {
    const filter: any = { user_id: userId }
    if (unreadOnly) filter.is_read = false

    return db.findMany('notifications', filter, { orderBy: 'created_at DESC', limit: 50 })
  }

  async markAsRead(id: number, userId: number): Promise<void> {
    await db.update('notifications', { id, user_id: userId }, { is_read: true })
  }

  async markAllAsRead(userId: number): Promise<void> {
    await db.updateMany('notifications', { user_id: userId, is_read: false }, { is_read: true })
  }

  async getUnreadCount(userId: number): Promise<number> {
    return db.count('notifications', { user_id: userId, is_read: false })
  }

  async deleteOld(days: number): Promise<number> {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - days)

    const result = await db.deleteMany('notifications', {
      created_at: { lt: cutoff },
      is_read: true,
    })
    return result.affected
  }
}
