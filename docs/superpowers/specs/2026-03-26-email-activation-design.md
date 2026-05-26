# Email Activation Registration Design

**Date:** 2026-03-26
**Scope:** Login/Register flow — email-based registration with activation

## Overview

Replace the current username-based registration with email-based registration. New users must verify their email address by clicking an activation link before they can log in.

## Database Changes

Modify the `users` table:

- `email` — change to `UNIQUE NOT NULL` (becomes the primary login identifier)
- `username` — retained for backward compatibility (admin user)
- `is_active BOOLEAN DEFAULT FALSE` — whether account is activated
- `activation_token VARCHAR(64)` — random token sent in activation email
- `token_expires_at TIMESTAMP` — 24 hours from registration

## Server (server.js)

### Dependencies
- Add `nodemailer` for SMTP email sending
- QQ SMTP: `smtp.qq.com`, port 465/587, account `704512454@qq.com`

### POST /api/register
1. Accept `email` + `password` (remove `username`)
2. Validate: email format, password >= 6 chars
3. If email exists AND `is_active = true` → return error "Email already registered"
4. If email exists AND `is_active = false` AND token expired → delete old record, allow re-registration
5. If email exists AND `is_active = false` AND token not expired → return error "Activation email already sent, please check your inbox"
6. Generate 64-char random hex `activation_token`, set `token_expires_at = NOW() + 24h`
7. Insert user with `is_active = false`
8. Send activation email via QQ SMTP with link: `https://<server>/api/activate?token=<token>`
9. Return `{ success: true, message: "Activation email sent" }`

### GET /api/activate?token=xxx
1. Look up user by `activation_token`
2. If not found → return HTML: "Invalid or expired activation link"
3. If `token_expires_at < NOW()` → return HTML: "Activation link expired. Please register again."
4. Set `is_active = true`, clear `activation_token` and `token_expires_at`
5. Return HTML: "Account activated successfully! You can now log in."

### POST /api/login
1. Query by `email` instead of `username`
2. If user not found or password wrong → "Invalid email or password"
3. If `is_active = false` → return `{ success: false, error: "Account not activated. Please check your email." }`
4. Issue JWT on success (same as before)

## Flutter (login_page.dart + api_service.dart)

### Register Form
- Remove Name field
- Keep: Email + Password
- On success: show message "Activation email sent. Please check your inbox." — stay on register tab, do NOT switch to login

### Login Form
- No visual changes
- Handle new error: "Account not activated. Please check your email."

### api_service.dart
- Change `register(name, password)` → `register(email, password)`
- Remove `name` parameter from request body

## Error Messages (App — English only)

| Scenario | Message |
|---|---|
| Empty fields | "Please fill in all fields" |
| Invalid email format | "Please enter a valid email address" |
| Email already registered | "Email already registered" |
| Activation email already sent | "Activation email already sent, please check your inbox" |
| Registration success | "Activation email sent. Please check your inbox." |
| Account not activated | "Account not activated. Please check your email." |
| Wrong credentials | "Invalid email or password" |
