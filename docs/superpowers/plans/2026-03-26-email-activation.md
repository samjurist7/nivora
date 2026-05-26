# Email Activation Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace username-based registration with email-based registration that requires email activation before login.

**Architecture:** Extend the existing `users` table with activation fields; add nodemailer-based email sending to server.js; update Flutter register/login flow to use email as the account identifier.

**Tech Stack:** Node.js + Express + PostgreSQL + nodemailer (QQ SMTP), Flutter + Dart

---

## File Map

| File | Change |
|---|---|
| `server.js` | Add nodemailer config, alter DB schema, rewrite `/api/register`, add `/api/activate`, update `/api/login` |
| `lib/services/api_service.dart` | Change `register(username, password)` → `register(email, password)`; change `login` body key `username` → `email` |
| `lib/pages/login_page.dart` | Remove Name field from register form; update `doRegister` call; update success/error messages |

---

### Task 1: Migrate database schema

**Files:**
- Modify: `server.js` — `initDatabase()` function (~line 173)

- [ ] **Step 1: Add migration logic inside `initDatabase()`**

Find the `initDatabase()` function and add these ALTER TABLE calls after the existing `CREATE TABLE IF NOT EXISTS users` block:

```js
// Email activation fields migration
await db.query(`
  ALTER TABLE users
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS activation_token VARCHAR(64),
    ADD COLUMN IF NOT EXISTS token_expires_at TIMESTAMP
`);

// Make email unique and required for new rows
// Note: existing rows with NULL email won't be affected by UNIQUE constraint
await db.query(`
  CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
    ON users (email) WHERE email IS NOT NULL
`);
```

- [ ] **Step 2: Restart server and verify migration runs without error**

```bash
node server.js
```

Expected: Server starts normally, no error about column already existing.

- [ ] **Step 3: Verify columns exist in database**

```bash
psql -U postgres -d iot_platform -c "\d users"
```

Expected: Columns `is_active`, `activation_token`, `token_expires_at` visible in output.

- [ ] **Step 4: Commit**

```bash
git add server.js
git commit -m "feat: add email activation columns to users table"
```

---

### Task 2: Add nodemailer SMTP configuration to server.js

**Files:**
- Modify: `server.js` — top of file, after existing `require` statements

- [ ] **Step 1: Add nodemailer require and transporter config**

After the existing `require` block (after `const fs = require('fs');`), add:

```js
const nodemailer = require('nodemailer');

const emailTransporter = nodemailer.createTransport({
  host: 'smtp.qq.com',
  port: 465,
  secure: true,
  auth: {
    user: '704512454@qq.com',
    pass: 'shmzanfaiqxubcaa',
  },
});

const SERVER_BASE_URL = 'http://43.138.237.99';
```

- [ ] **Step 2: Add sendActivationEmail helper function**

Add this function after the `authenticateToken` middleware (~line 300):

```js
async function sendActivationEmail(email, token) {
  const activationUrl = `${SERVER_BASE_URL}/api/activate?token=${token}`;
  await emailTransporter.sendMail({
    from: '"ShishaX" <704512454@qq.com>',
    to: email,
    subject: 'Activate your ShishaX account',
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto">
        <h2>Activate your account</h2>
        <p>Click the button below to activate your ShishaX account. This link expires in 24 hours.</p>
        <a href="${activationUrl}"
           style="display:inline-block;padding:12px 24px;background:#FF512F;color:#fff;border-radius:6px;text-decoration:none;font-weight:600">
          Activate Account
        </a>
        <p style="color:#888;font-size:12px;margin-top:24px">
          If you did not register, ignore this email.
        </p>
      </div>
    `,
  });
}
```

- [ ] **Step 3: Commit**

```bash
git add server.js
git commit -m "feat: add nodemailer QQ SMTP config and activation email helper"
```

---

### Task 3: Rewrite /api/register endpoint

**Files:**
- Modify: `server.js` — `app.post('/api/register', ...)` block (~line 306)

- [ ] **Step 1: Replace the existing /api/register handler entirely**

Delete the old handler from `app.post('/api/register'` to its closing `});` and replace with:

```js
// 用户注册（邮箱 + 密码，需邮箱激活）
app.post('/api/register', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Email and password are required' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ success: false, error: 'Please enter a valid email address' });
    }

    if (password.length < 6) {
      return res.status(400).json({ success: false, error: 'Password must be at least 6 characters' });
    }

    const existing = await db.query('SELECT id, is_active, token_expires_at FROM users WHERE email = $1', [email]);

    if (existing.rows.length > 0) {
      const user = existing.rows[0];
      if (user.is_active) {
        return res.status(400).json({ success: false, error: 'Email already registered' });
      }
      // Not activated — check if token expired
      if (user.token_expires_at && new Date(user.token_expires_at) > new Date()) {
        return res.status(400).json({ success: false, error: 'Activation email already sent, please check your inbox' });
      }
      // Token expired — delete stale record so user can re-register
      await db.query('DELETE FROM users WHERE email = $1', [email]);
    }

    const crypto = require('crypto');
    const activationToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const passwordHash = await bcrypt.hash(password, 10);

    const result = await db.query(
      `INSERT INTO users (username, password_hash, email, is_active, activation_token, token_expires_at)
       VALUES ($1, $2, $3, false, $4, $5) RETURNING id`,
      [email, passwordHash, email, activationToken, expiresAt]
    );

    await sendActivationEmail(email, activationToken);

    console.log(`✓ 新用户注册（待激活）: ${email} (ID: ${result.rows[0].id})`);
    res.json({ success: true, message: 'Activation email sent' });
  } catch (error) {
    console.error('注册失败:', error);
    res.status(500).json({ success: false, error: 'Registration failed, please try again' });
  }
});
```

Note: `username` is set to `email` value to satisfy the existing `UNIQUE NOT NULL` constraint on `username` without schema breakage.

- [ ] **Step 2: Commit**

```bash
git add server.js
git commit -m "feat: rewrite register endpoint to use email + activation flow"
```

---

### Task 4: Add /api/activate endpoint

**Files:**
- Modify: `server.js` — add new route after `/api/register`

- [ ] **Step 1: Add the activation route**

Directly after the `/api/register` handler, add:

```js
// 邮箱激活
app.get('/api/activate', async (req, res) => {
  try {
    const { token } = req.query;

    if (!token) {
      return res.send(activationPage('Invalid Link', 'No activation token provided.', false));
    }

    const result = await db.query(
      'SELECT id, token_expires_at FROM users WHERE activation_token = $1',
      [token]
    );

    if (result.rows.length === 0) {
      return res.send(activationPage('Invalid Link', 'This activation link is invalid or has already been used.', false));
    }

    const user = result.rows[0];
    if (new Date(user.token_expires_at) < new Date()) {
      await db.query('DELETE FROM users WHERE id = $1', [user.id]);
      return res.send(activationPage('Link Expired', 'Your activation link has expired. Please register again.', false));
    }

    await db.query(
      'UPDATE users SET is_active = true, activation_token = NULL, token_expires_at = NULL WHERE id = $1',
      [user.id]
    );

    res.send(activationPage('Account Activated!', 'Your account has been activated successfully. You can now log in to the ShishaX app.', true));
  } catch (error) {
    console.error('激活失败:', error);
    res.send(activationPage('Error', 'Something went wrong. Please try again.', false));
  }
});

function activationPage(title, message, success) {
  const color = success ? '#FF512F' : '#888';
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>${title}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>body{font-family:sans-serif;background:#111;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0}
.box{text-align:center;padding:40px;max-width:400px}
h1{color:${color}}p{color:#aaa}</style></head>
<body><div class="box"><h1>${title}</h1><p>${message}</p></div></body></html>`;
}
```

- [ ] **Step 2: Commit**

```bash
git add server.js
git commit -m "feat: add /api/activate endpoint with HTML response page"
```

---

### Task 5: Update /api/login to use email and check is_active

**Files:**
- Modify: `server.js` — `app.post('/api/login', ...)` block (~line 367)

- [ ] **Step 1: Replace login handler**

Delete the existing `/api/login` handler and replace with:

```js
// 用户登录
app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await db.query(
      'SELECT id, password_hash, is_active, username FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);

    if (!valid) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (!user.is_active) {
      return res.status(403).json({ success: false, error: 'Account not activated. Please check your email.' });
    }

    const token = jwt.sign(
      { user_id: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({ success: true, token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

- [ ] **Step 2: Ensure admin user is activated in DB (run once)**

```bash
psql -U postgres -d iot_platform -c "UPDATE users SET is_active = true WHERE username = 'admin';"
```

Expected: `UPDATE 1`

- [ ] **Step 3: Commit**

```bash
git add server.js
git commit -m "feat: update login to use email and enforce is_active check"
```

---

### Task 6: Update api_service.dart

**Files:**
- Modify: `lib/services/api_service.dart`

- [ ] **Step 1: Update `login()` to send `email` key instead of `username`**

Find in `api_service.dart` (~line 114):
```dart
{'username': username, 'password': password},
```
Change to:
```dart
{'email': username, 'password': password},
```
(The parameter name `username` stays as-is since it receives an email string from the caller.)

- [ ] **Step 2: Update `register()` signature and body**

Find (~line 141):
```dart
Future<Map<String, dynamic>> register(
    String username, String password) async {
  try {
    final response = await _post(
      ApiConfig.registerEndpoint,
      {'username': username, 'password': password},
    );
```
Replace with:
```dart
Future<Map<String, dynamic>> register(
    String email, String password) async {
  try {
    final response = await _post(
      ApiConfig.registerEndpoint,
      {'email': email, 'password': password},
    );
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "feat: update api_service to send email field for login and register"
```

---

### Task 7: Update login_page.dart

**Files:**
- Modify: `lib/pages/login_page.dart`

- [ ] **Step 1: Remove `_nameCtrl` and Name field**

Remove line ~19:
```dart
final _nameCtrl = TextEditingController();
```

Remove from `dispose()`:
```dart
_nameCtrl.dispose();
```

- [ ] **Step 2: Update `doRegister()`**

Replace the entire `doRegister()` method:

```dart
void doRegister() async {
  final email = _emailCtrl.text.trim();
  final password = _passCtrl.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill in all fields'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!emailRegex.hasMatch(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid email address'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => loading = true);

  final api = Provider.of<ApiService>(context, listen: false);
  final result = await api.register(email, password);

  setState(() => loading = false);

  if (!mounted) return;

  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Activation email sent. Please check your inbox.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
      ),
    );
    // Stay on register tab — user must activate before logging in
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error'] ?? 'Registration failed'),
        backgroundColor: MechanicalTheme.warningRed,
      ),
    );
  }
}
```

- [ ] **Step 3: Update `_buildRegisterForm()` — remove Name field**

Replace the entire `_buildRegisterForm()` method:

```dart
Widget _buildRegisterForm() {
  return Column(
    children: [
      _buildTextField(
        controller: _emailCtrl,
        label: 'EMAIL',
        hint: 'your@email.com',
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _passCtrl,
        label: 'PASSWORD',
        hint: '••••••••',
        obscureText: true,
      ),
      const SizedBox(height: 24),
      _buildActionGradientButton(
        text: 'CREATE ACCOUNT',
        onTap: loading ? null : doRegister,
      ),
      const SizedBox(height: 16),
      _buildForgotPasswordLink(),
    ],
  );
}
```

- [ ] **Step 4: Remove default test credentials from login controllers**

Change line ~17-18 from:
```dart
final _emailCtrl = TextEditingController(text: 'admin');
final _passCtrl = TextEditingController(text: '123456');
```
To:
```dart
final _emailCtrl = TextEditingController();
final _passCtrl = TextEditingController();
```

- [ ] **Step 5: Commit**

```bash
git add lib/pages/login_page.dart
git commit -m "feat: update login page - email-only register form, activation messaging"
```

---

### Task 8: End-to-end test

- [ ] **Step 1: Start server**
```bash
node server.js
```

- [ ] **Step 2: Test register with new email**
```bash
curl -X POST http://localhost:3000/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456"}'
```
Expected: `{"success":true,"message":"Activation email sent"}`

- [ ] **Step 3: Verify activation email arrives in inbox**

Check `test@example.com` inbox for email from ShishaX with activation link.

- [ ] **Step 4: Test login before activation**
```bash
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456"}'
```
Expected: `{"success":false,"error":"Account not activated. Please check your email."}`

- [ ] **Step 5: Click activation link in email**

Open the link in a browser. Expected: Green "Account Activated!" page.

- [ ] **Step 6: Test login after activation**
```bash
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456"}'
```
Expected: `{"success":true,"token":"<jwt>"}`

- [ ] **Step 7: Build and test Flutter app**
```bash
flutter run
```
- Register with a real email → see "Activation email sent" snackbar
- Try login before activating → see "Account not activated" error
- Activate via email link → login succeeds, navigates to ChoosePage
