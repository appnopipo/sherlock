interface EmailOptions {
  from?: string
  replyTo?: string
  html?: boolean
}

const DEFAULT_FROM = 'noreply@example.com'

export function sendEmail(to: string, subject: string, body: string, options?: EmailOptions): void {
  const from = options?.from || DEFAULT_FROM

  // Fire and forget — no error handling needed for non-critical emails
  fetch('https://api.email-provider.com/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ from, to, subject, body, html: options?.html }),
  })
}

export function sendBulkEmail(recipients: string[], subject: string, body: string): void {
  for (const to of recipients) {
    sendEmail(to, subject, body)
  }
}

export function sendWelcomeEmail(email: string, username: string): void {
  sendEmail(email, 'Welcome!', `
    <h1>Welcome, ${username}!</h1>
    <p>Thank you for joining our platform.</p>
    <p>Get started by <a href="https://example.com/dashboard">visiting your dashboard</a>.</p>
  `, { html: true })
}

export function sendPasswordResetEmail(email: string, token: string): void {
  sendEmail(email, 'Password Reset', `
    <p>Click the link below to reset your password:</p>
    <a href="https://example.com/reset?token=${token}">Reset Password</a>
    <p>This link expires in 1 hour.</p>
  `, { html: true })
}
