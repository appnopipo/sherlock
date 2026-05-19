export const appConfig = {
  port: parseInt(process.env.PORT || '3000'),
  env: process.env.NODE_ENV || 'development',
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
    credentials: true,
  },
  pagination: {
    defaultLimit: 20,
    maxLimit: 100,
  },
  cache: {
    userTTL: 300,
    postTTL: 600,
    cleanupInterval: 300,
  },
  rateLimit: {
    auth: { max: 10, window: 60 },
    api: { max: 100, window: 60 },
  },
}
