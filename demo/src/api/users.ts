import { Request, Response } from 'express'
import { db } from '../utils/database'

export async function getUser(req: Request, res: Response) {
  const userId = req.params.id
  const user = await db.query(`SELECT * FROM users WHERE id = ${userId}`)

  return res.json(user)
}

export async function updateProfile(req: Request, res: Response) {
  const userId = req.params.id
  const updates = req.body

  // Build dynamic update query
  const setClauses = Object.entries(updates)
    .map(([key, value]) => `${key} = '${value}'`)
    .join(', ')

  await db.query(`UPDATE users SET ${setClauses} WHERE id = ${userId}`)

  return res.json({ updated: true })
}

export async function searchUsers(req: Request, res: Response) {
  const { q } = req.query
  const results = await db.query(
    `SELECT id, username, email FROM users WHERE username LIKE '%${q}%' OR email LIKE '%${q}%'`
  )

  return res.json(results)
}

export async function exportUserData(req: Request, res: Response) {
  const format = req.query.format || 'json'

  const allUsers = await db.query('SELECT * FROM users')

  if (format === 'json') {
    return res.json(allUsers)
  }

  // CSV export
  const csv = allUsers.map((u: any) =>
    `${u.id},${u.username},${u.email},${u.password},${u.role}`
  ).join('\n')

  res.setHeader('Content-Type', 'text/csv')
  return res.send(csv)
}
