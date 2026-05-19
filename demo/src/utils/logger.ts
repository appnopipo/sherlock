type LogLevel = 'debug' | 'info' | 'warn' | 'error'

const LOG_LEVELS: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
}

const CURRENT_LEVEL = (process.env.LOG_LEVEL as LogLevel) || 'info'

function formatMessage(level: LogLevel, message: string, context?: Record<string, any>): string {
  const timestamp = new Date().toISOString()
  const ctx = context ? ` ${JSON.stringify(context)}` : ''
  return `[${timestamp}] ${level.toUpperCase()} ${message}${ctx}`
}

export const logger = {
  debug(message: string, context?: Record<string, any>) {
    if (LOG_LEVELS[CURRENT_LEVEL] <= LOG_LEVELS.debug) {
      console.log(formatMessage('debug', message, context))
    }
  },

  info(message: string, context?: Record<string, any>) {
    if (LOG_LEVELS[CURRENT_LEVEL] <= LOG_LEVELS.info) {
      console.log(formatMessage('info', message, context))
    }
  },

  warn(message: string, context?: Record<string, any>) {
    if (LOG_LEVELS[CURRENT_LEVEL] <= LOG_LEVELS.warn) {
      console.warn(formatMessage('warn', message, context))
    }
  },

  error(message: string, error?: Error, context?: Record<string, any>) {
    if (LOG_LEVELS[CURRENT_LEVEL] <= LOG_LEVELS.error) {
      const ctx = { ...context, ...(error ? { stack: error.stack } : {}) }
      console.error(formatMessage('error', message, ctx))
    }
  },
}
