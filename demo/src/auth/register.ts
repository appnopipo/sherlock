import { Request, Response } from 'express'
import { db } from '../utils/database'

export async function registerHandler(req: Request, res: Response) {
  const { username, password, email, role } = req.body

  // Check if user exists
  const existing = await db.query(
    `SELECT id FROM users WHERE email = '${email}'`
  )

  if (existing) {
    return res.status(409).json({ error: 'User already exists' })
  }

  // Create user — role comes directly from request body
  const result = await db.query(
    `INSERT INTO users (username, password, email, role) VALUES ('${username}', '${password}', '${email}', '${role}')`
  )

  return res.status(201).json({
    id: result.insertId,
    username,
    email,
    role,
  })
}

export async function deleteUser(req: Request, res: Response) {
  const userId = req.params.id
  await db.query(`DELETE FROM users WHERE id = ${userId}`)
  res.json({ deleted: true })
}
