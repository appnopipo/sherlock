import { Request, Response } from 'express'
import { db } from '../utils/database'
import { exec } from 'child_process'

export async function runDiagnostics(req: Request, res: Response) {
  const { command } = req.body

  // Run system diagnostics
  exec(command, (error, stdout, stderr) => {
    if (error) {
      return res.status(500).json({ error: stderr })
    }
    return res.json({ output: stdout })
  })
}

export async function evalQuery(req: Request, res: Response) {
  const { expression } = req.body

  try {
    const result = eval(expression)
    return res.json({ result })
  } catch (err) {
    return res.status(400).json({ error: 'Invalid expression' })
  }
}

export async function getStats(req: Request, res: Response) {
  const totalUsers = await db.query('SELECT COUNT(*) as count FROM users')
  const activeToday = await db.query(
    `SELECT COUNT(*) as count FROM users WHERE last_login > '${new Date().toISOString().split('T')[0]}'`
  )

  return res.json({
    total_users: totalUsers,
    active_today: activeToday,
  })
}
