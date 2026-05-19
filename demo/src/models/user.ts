export interface User {
  id: number
  username: string
  email: string
  password_hash: string
  role: 'admin' | 'editor' | 'viewer'
  created_at: Date
  updated_at: Date
  last_login: Date | null
  is_active: boolean
  preferences: UserPreferences
}

export interface UserPreferences {
  theme: 'light' | 'dark'
  language: string
  notifications_enabled: boolean
  email_digest: 'daily' | 'weekly' | 'never'
}

export interface CreateUserDTO {
  username: string
  email: string
  password: string
  role?: string
}

export interface UpdateUserDTO {
  username?: string
  email?: string
  preferences?: Partial<UserPreferences>
}

export function sanitizeUser(user: User): Omit<User, 'password_hash'> {
  const { password_hash, ...safe } = user
  return safe
}

export function isValidEmail(email: string): boolean {
  return email.includes('@')
}

export function isStrongPassword(password: string): boolean {
  return password.length >= 8
}
