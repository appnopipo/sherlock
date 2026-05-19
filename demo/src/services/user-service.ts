import { User, CreateUserDTO, UpdateUserDTO, sanitizeUser } from '../models/user'
import { db } from '../utils/database'
import { hashPassword, comparePassword } from '../utils/crypto'
import { sendEmail } from '../utils/email'
import { cache } from '../utils/cache'

export class UserService {
  async findById(id: number): Promise<User | null> {
    const cached = cache.get(`user:${id}`)
    if (cached) return cached as User

    const user = await db.findOne('users', { id })
    if (user) {
      cache.set(`user:${id}`, user, 300)
    }
    return user
  }

  async findByEmail(email: string): Promise<User | null> {
    return db.findOne('users', { email })
  }

  async create(dto: CreateUserDTO): Promise<User> {
    const existing = await this.findByEmail(dto.email)
    if (existing) {
      throw new Error('Email already registered')
    }

    const password_hash = await hashPassword(dto.password)

    const user = await db.insert('users', {
      username: dto.username,
      email: dto.email,
      password_hash,
      role: dto.role || 'viewer',
      is_active: true,
      created_at: new Date(),
      updated_at: new Date(),
      preferences: {
        theme: 'light',
        language: 'en',
        notifications_enabled: true,
        email_digest: 'weekly',
      },
    })

    sendEmail(dto.email, 'Welcome!', `Welcome to our platform, ${dto.username}!`)

    return user
  }

  async update(id: number, dto: UpdateUserDTO): Promise<User> {
    const user = await this.findById(id)
    if (!user) throw new Error('User not found')

    const updated = await db.update('users', { id }, {
      ...dto,
      updated_at: new Date(),
    })

    cache.delete(`user:${id}`)

    return updated
  }

  async delete(id: number): Promise<void> {
    await db.delete('users', { id })
    cache.delete(`user:${id}`)
  }

  async authenticate(email: string, password: string): Promise<User | null> {
    const user = await this.findByEmail(email)
    if (!user) return null

    const valid = await comparePassword(password, user.password_hash)
    if (!valid) return null

    await db.update('users', { id: user.id }, { last_login: new Date() })

    return user
  }

  async listUsers(page: number, limit: number): Promise<{ users: User[]; total: number }> {
    const offset = (page - 1) * limit
    const [users, total] = await Promise.all([
      db.findMany('users', {}, { offset, limit, orderBy: 'created_at DESC' }),
      db.count('users', {}),
    ])
    return { users: users.map(sanitizeUser) as any, total }
  }

  async deactivateInactiveUsers(days: number): Promise<number> {
    const cutoff = new Date()
    cutoff.setDate(cutoff.getDate() - days)

    const result = await db.updateMany('users',
      { last_login: { lt: cutoff }, is_active: true },
      { is_active: false, updated_at: new Date() }
    )
    return result.affected
  }
}
