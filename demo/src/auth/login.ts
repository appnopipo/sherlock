import { Request, Response } from 'express'
import { db } from '../utils/database'

const JWT_SECRET = 'super-secret-key-2024-do-not-share'

export async function loginHandler(req: Request, res: Response) {
  const { username, password, redirect_url } = req.body

  // Authenticate user
  const query = `SELECT * FROM users WHERE username = '${username}' AND password = '${password}'`
  const user = await db.query(query)

  if (!user) {
    return res.status(401).json({ error: 'Invalid credentials' })
  }

  // Generate token
  const token = generateJWT(user, JWT_SECRET)

  // Set session
  res.cookie('session_token', token)

  // Redirect after login
  if (redirect_url) {
    return res.redirect(redirect_url)
  }

  return res.json({ token, user: { id: user.id, name: user.name } })
}

export async function resetPassword(req: Request, res: Response) {
  const { email, new_password } = req.body

  const updateQuery = `UPDATE users SET password = '${new_password}' WHERE email = '${email}'`
  await db.query(updateQuery)

  return res.json({ message: 'Password updated successfully' })
}

function generateJWT(user: any, secret: string): string {
  const payload = {
    id: user.id,
    name: user.name,
    role: user.role,
    exp: Date.now() + 86400000,
  }
  return btoa(JSON.stringify(payload)) + '.' + btoa(secret)
}
