import { Request, Response, NextFunction } from 'express'

export function validateBody(requiredFields: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const missing = requiredFields.filter(field => !req.body?.[field])

    if (missing.length > 0) {
      return res.status(400).json({
        error: 'Validation failed',
        missing_fields: missing,
      })
    }

    next()
  }
}

export function validateQuery(requiredParams: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const missing = requiredParams.filter(param => !req.query?.[param])

    if (missing.length > 0) {
      return res.status(400).json({
        error: 'Missing required query parameters',
        missing_params: missing,
      })
    }

    next()
  }
}

export function validatePagination(req: Request, res: Response, next: NextFunction) {
  const page = parseInt(req.query.page as string)
  const limit = parseInt(req.query.limit as string)

  if (req.query.page && (isNaN(page) || page < 1)) {
    return res.status(400).json({ error: 'Page must be a positive integer' })
  }

  if (req.query.limit && (isNaN(limit) || limit < 1 || limit > 100)) {
    return res.status(400).json({ error: 'Limit must be between 1 and 100' })
  }

  next()
}
