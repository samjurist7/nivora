/*
 * 云服务器后端 API
 * 功能：
 * - 用户认证与授权
 * - 设备管理
 * - 远程控制
 * - 数据查询
 * - WebSocket 实时推送
 */

const express = require('express');
const mqtt = require('mqtt');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');
const Redis = require('ioredis');
const WebSocket = require('ws');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const nodemailer = require('nodemailer');

const SERVER_BASE_URL = 'http://43.138.237.99';

const emailTransporter = nodemailer.createTransport({
  host: 'smtp.qq.com',
  port: 465,
  secure: true,
  auth: {
    user: '704512454@qq.com',
    pass: 'shmzanfaiqxubcaa',
  },
});

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

async function sendPasswordResetEmail(email, token) {
  const resetUrl = `${SERVER_BASE_URL}/api/reset-password?token=${token}`;
  await emailTransporter.sendMail({
    from: '"ShishaX" <704512454@qq.com>',
    to: email,
    subject: 'Reset your ShishaX password',
    html: `
      <div style="font-family:sans-serif;max-width:480px;margin:auto">
        <h2 style="color:#FF512F">Reset your password</h2>
        <p>We received a request to reset your password. Click the button below to choose a new password. This link expires in 1 hour.</p>
        <a href="${resetUrl}"
           style="display:inline-block;padding:12px 24px;background:linear-gradient(90deg,#FF512F,#FF6B35);color:#fff;border-radius:6px;text-decoration:none;font-weight:600">
          Reset Password
        </a>
        <p style="color:#888;font-size:12px;margin-top:24px">
          If you did not request a password reset, ignore this email. Your password will not change.
        </p>
      </div>
    `,
  });
}

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// 🔥 修改：改为固定文件名 firmware.bin 🔥
app.use('/firmware', express.static(path.join(__dirname, 'uploads')));
app.use('/video', express.static(path.join(__dirname, 'video')));
app.use('/spiffs_files', express.static(path.join(__dirname, 'uploads/spiffs_files')));

// 🔥 修改：multer配置改为固定文件名 🔥
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    // 确保 uploads 目录存在
    if (!fs.existsSync('uploads')) {
      fs.mkdirSync('uploads');
    }
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    // 🔥 关键修改：固定文件名为 firmware.bin 🔥
    cb(null, 'firmware.bin');
  }
});
const upload = multer({
  storage: storage,
  fileFilter: (req, file, cb) => {
    if (file.originalname.endsWith('.bin')) {
      cb(null, true);
    } else {
      cb(new Error('只允许上传 .bin 文件'));
    }
  }
});

// SPIFFS OTA 文件上传配置
const spiffsStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    if (!fs.existsSync('uploads')) fs.mkdirSync('uploads');
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    cb(null, 'spiffs.bin');
  }
});
const spiffsUpload = multer({
  storage: spiffsStorage,
  fileFilter: (req, file, cb) => {
    if (file.originalname.endsWith('.bin')) cb(null, true);
    else cb(new Error('只允许上传 .bin 文件'));
  }
});

// SD Card 文件上传配置
const sdcardStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    if (!fs.existsSync('uploads')) {
      fs.mkdirSync('uploads');
    }
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    cb(null, 'sdcard.tar');
  }
});
const sdcardUpload = multer({
  storage: sdcardStorage,
  fileFilter: (req, file, cb) => {
    if (file.originalname.endsWith('.tar')) {
      cb(null, true);
    } else {
      cb(new Error('只允许上传 .tar 文件'));
    }
  }
});

// SPIFFS 单文件上传配置（保留原始文件名，存到 uploads/spiffs_files/）
const spiffsFileStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = path.join(__dirname, 'uploads/spiffs_files');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const preset = req.query.preset;
    if (preset !== undefined && /^[0-5]$/.test(preset)) {
      cb(null, `preset_${preset}.png`);
    } else {
      cb(null, file.originalname);
    }
  }
});
const spiffsFileUpload = multer({
  storage: spiffsFileStorage,
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (['.png', '.jpg', '.jpeg', '.bin', '.gif'].includes(ext)) cb(null, true);
    else cb(new Error('只允许上传图片或 .bin 文件'));
  },
  limits: { fileSize: 5 * 1024 * 1024 } // 5MB
});

// 屏保视频上传临时存储配置
const screensaverVideoStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = path.join(__dirname, 'uploads/screensaver_tmp');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    cb(null, dir);
  },
  filename: (req, file, cb) => cb(null, `upload_${Date.now()}${path.extname(file.originalname)}`)
});
const screensaverVideoUpload = multer({
  storage: screensaverVideoStorage,
  fileFilter: (req, file, cb) => {
    const allowed = ['.mp4', '.mov', '.avi', '.webm', '.mkv'];
    cb(null, allowed.includes(path.extname(file.originalname).toLowerCase()));
  },
  limits: { fileSize: 100 * 1024 * 1024 }
});

// ==================== 配置 ====================
const PORT = 3000;
const JWT_SECRET = 'MyApp2025!SecretKey#IoTPlatform@Qwerty123';
const MQTT_BROKER = 'mqtt://localhost:1883';
const MQTT_OPTIONS = {
  username: 'admin',
  password: 'admin123'
};

// 数据库连接
const db = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'iot_platform',
  user: 'postgres',
  password: '704512'
});

// Redis 连接
const redis = new Redis({
  host: 'localhost',
  port: 6379
});

// MQTT 客户端
const mqttClient = mqtt.connect(MQTT_BROKER, MQTT_OPTIONS);

// WebSocket 服务器
const wss = new WebSocket.Server({ noServer: true });

// ==================== 数据库初始化 ====================
async function initDatabase() {
  // 用户表
  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      email VARCHAR(100),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // 邮箱激活字段迁移（idempotent，重复启动无害）
  await db.query(`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT FALSE,
      ADD COLUMN IF NOT EXISTS activation_token VARCHAR(64),
      ADD COLUMN IF NOT EXISTS token_expires_at TIMESTAMP
  `);
  await db.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
      ON users (email) WHERE email IS NOT NULL
  `);
  
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

  // Display name field migration
  await db.query(`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS name VARCHAR(100)
  `);

  // Password reset fields migration
  await db.query(`
    ALTER TABLE users
      ADD COLUMN IF NOT EXISTS reset_token VARCHAR(64),
      ADD COLUMN IF NOT EXISTS reset_token_expires_at TIMESTAMP
  `);

  // 设备表
  await db.query(`
    CREATE TABLE IF NOT EXISTS devices (
      id SERIAL PRIMARY KEY,
      device_id VARCHAR(50) UNIQUE NOT NULL,
      device_type VARCHAR(50),
      owner_id INTEGER REFERENCES users(id),
      name VARCHAR(100),
      firmware_version VARCHAR(20),
      status VARCHAR(20) DEFAULT 'offline',
      last_online TIMESTAMP,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  // 设备数据表
  await db.query(`
    CREATE TABLE IF NOT EXISTS device_data (
      id SERIAL PRIMARY KEY,
      device_id VARCHAR(50) NOT NULL,
      data_type VARCHAR(50),
      data JSONB,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  // 控制日志表
  await db.query(`
    CREATE TABLE IF NOT EXISTS control_logs (
      id SERIAL PRIMARY KEY,
      device_id VARCHAR(50) NOT NULL,
      user_id INTEGER REFERENCES users(id),
      action VARCHAR(100),
      result VARCHAR(20),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
  
  console.log('✓ 数据库初始化完成');
}

// ==================== MQTT 事件处理 ====================
mqttClient.on('connect', () => {
  console.log('✓ MQTT 已连接');
  
  // 订阅所有设备主题
  mqttClient.subscribe('device/+/status');
  mqttClient.subscribe('device/+/data');
  mqttClient.subscribe('device/+/sdcard_result');
  mqttClient.subscribe('device/+/spiffs_ota_result');
  mqttClient.subscribe('device/+/spiffs_file_result');
});

mqttClient.on('message', async (topic, message) => {
  try {
    const data = JSON.parse(message.toString());
    const deviceId = topic.split('/')[1];
    
    // 更新设备状态到 Redis
    await redis.setex(`device:${deviceId}:status`, 300, JSON.stringify(data));
    
    // 处理不同类型的消息
    if (topic.includes('/status')) {
      await handleDeviceStatus(deviceId, data);
    } else if (topic.includes('/data')) {
      await handleDeviceData(deviceId, data);
    }
    
    // 通过 WebSocket 推送给客户端
    broadcastToClients({
      type: 'device_update',
      device_id: deviceId,
      data: data
    });
    
  } catch (error) {
    console.error('处理 MQTT 消息失败:', error);
  }
});

// 处理设备状态更新
async function handleDeviceStatus(deviceId, data) {
  await db.query(
    `UPDATE devices 
     SET status = $1, last_online = CURRENT_TIMESTAMP, firmware_version = $2
     WHERE device_id = $3`,
    [data.status || 'online', data.firmware, deviceId]
  );
}

// 处理设备数据
async function handleDeviceData(deviceId, data) {
  await db.query(
    `INSERT INTO device_data (device_id, data_type, data)
     VALUES ($1, $2, $3)`,
    [deviceId, 'sensor', data]
  );
}

// ==================== 中间件 ====================
// JWT 验证
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: '未提供认证令牌' });
  }
  
  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: '令牌无效' });
    }
    req.user = user;
    next();
  });
}

// ==================== API 路由 ====================

// 用户注册（邮箱 + 密码，需邮箱激活）
app.post('/api/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;

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

    const existing = await db.query(
      'SELECT id, is_active, token_expires_at FROM users WHERE email = $1',
      [email]
    );

    if (existing.rows.length > 0) {
      const user = existing.rows[0];
      if (user.is_active) {
        return res.status(400).json({ success: false, error: 'Email already registered' });
      }
      // 未激活：token 未过期则提示检查邮箱
      if (user.token_expires_at && new Date(user.token_expires_at) > new Date()) {
        return res.status(400).json({ success: false, error: 'Activation email already sent, please check your inbox' });
      }
      // token 已过期：删除旧记录，允许重新注册
      await db.query('DELETE FROM users WHERE email = $1', [email]);
    }

    const activationToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const passwordHash = await bcrypt.hash(password, 10);

    // username 设为 email，满足现有 UNIQUE NOT NULL 约束
    const result = await db.query(
      `INSERT INTO users (username, password_hash, email, name, is_active, activation_token, token_expires_at)
       VALUES ($1, $2, $3, $4, false, $5, $6) RETURNING id`,
      [email, passwordHash, email, name || null, activationToken, expiresAt]
    );

    await sendActivationEmail(email, activationToken);

    console.log(`✓ 新用户注册（待激活）: ${email} (ID: ${result.rows[0].id})`);
    res.json({ success: true, message: 'Activation email sent' });
  } catch (error) {
    console.error('注册失败:', error);
    res.status(500).json({ success: false, error: 'Registration failed, please try again' });
  }
});

// 隐私政策页面
app.get('/privacy', (req, res) => {
  res.sendFile(path.join(__dirname, 'privacy_policy.html'));
});

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

// 用户登录
app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const result = await db.query(
      'SELECT id, password_hash, is_active, username, name FROM users WHERE email = $1',
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

    res.json({ success: true, token, name: user.name || null });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 忘记密码 - 发送重置邮件
app.post('/api/forgot-password', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, error: 'Email is required' });
    }

    const result = await db.query('SELECT id FROM users WHERE email = $1 AND is_active = true', [email]);
    // 无论邮箱是否存在都返回成功，防止用户枚举
    if (result.rows.length === 0) {
      return res.json({ success: true });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1小时

    await db.query(
      'UPDATE users SET reset_token = $1, reset_token_expires_at = $2 WHERE email = $3',
      [resetToken, expiresAt, email]
    );

    await sendPasswordResetEmail(email, resetToken);
    console.log(`✓ 密码重置邮件已发送: ${email}`);
    res.json({ success: true });
  } catch (error) {
    console.error('忘记密码失败:', error);
    res.status(500).json({ success: false, error: 'Failed to send reset email' });
  }
});

// 重置密码页面（网页）
app.get('/api/reset-password', async (req, res) => {
  const { token } = req.query;
  if (!token) {
    return res.send(resetPasswordPage('Invalid Link', null, 'No reset token provided.', false));
  }

  const result = await db.query(
    'SELECT id, reset_token_expires_at FROM users WHERE reset_token = $1',
    [token]
  );

  if (result.rows.length === 0) {
    return res.send(resetPasswordPage('Invalid Link', null, 'This reset link is invalid or has already been used.', false));
  }

  if (new Date(result.rows[0].reset_token_expires_at) < new Date()) {
    return res.send(resetPasswordPage('Link Expired', null, 'This reset link has expired. Please request a new one.', false));
  }

  res.send(resetPasswordPage('Reset Password', token, null, true));
});

// 重置密码提交
app.post('/api/reset-password', async (req, res) => {
  try {
    const { token, password } = req.body;

    if (!token || !password) {
      return res.send(resetPasswordPage('Error', null, 'Token and password are required.', false));
    }

    if (password.length < 6) {
      return res.send(resetPasswordPage('Error', token, 'Password must be at least 6 characters.', true));
    }

    const result = await db.query(
      'SELECT id, reset_token_expires_at FROM users WHERE reset_token = $1',
      [token]
    );

    if (result.rows.length === 0) {
      return res.send(resetPasswordPage('Invalid Link', null, 'This reset link is invalid or has already been used.', false));
    }

    if (new Date(result.rows[0].reset_token_expires_at) < new Date()) {
      return res.send(resetPasswordPage('Link Expired', null, 'This reset link has expired. Please request a new one.', false));
    }

    const passwordHash = await bcrypt.hash(password, 10);
    await db.query(
      'UPDATE users SET password_hash = $1, reset_token = NULL, reset_token_expires_at = NULL WHERE id = $2',
      [passwordHash, result.rows[0].id]
    );

    res.send(resetPasswordPage('Password Updated!', null, 'Your password has been reset successfully. You can now log in to the ShishaX app.', false, true));
  } catch (error) {
    console.error('重置密码失败:', error);
    res.send(resetPasswordPage('Error', null, 'Something went wrong. Please try again.', false));
  }
});

function resetPasswordPage(title, token, message, showForm, success = false) {
  const color = success ? '#FF512F' : (showForm ? '#FF512F' : '#888');
  const formHtml = showForm ? `
    <form method="POST" action="/api/reset-password" style="margin-top:24px">
      <input type="hidden" name="token" value="${token}">
      <input type="password" name="password" placeholder="New password (min 6 characters)"
        style="width:100%;padding:12px 16px;background:#1a1a1a;border:1px solid #333;border-radius:8px;color:#fff;font-size:14px;box-sizing:border-box;margin-bottom:12px">
      <input type="password" name="confirm" placeholder="Confirm new password"
        style="width:100%;padding:12px 16px;background:#1a1a1a;border:1px solid #333;border-radius:8px;color:#fff;font-size:14px;box-sizing:border-box;margin-bottom:20px">
      <button type="submit"
        style="width:100%;padding:12px;background:linear-gradient(90deg,#FF512F,#FF6B35);color:#fff;border:none;border-radius:8px;font-size:15px;font-weight:600;cursor:pointer;letter-spacing:1px">
        SET NEW PASSWORD
      </button>
    </form>` : '';
  const msgHtml = message ? `<p style="color:#aaa;margin-top:16px">${message}</p>` : '';
  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>${title}</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>*{box-sizing:border-box}body{font-family:sans-serif;background:#111;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px}
.box{width:100%;max-width:420px;background:#1a1a1a;border:1px solid #2a2a2a;border-radius:16px;padding:32px 28px;text-align:center}
h1{color:${color};font-size:22px;margin-bottom:8px}
input::placeholder{color:#555}input:focus{outline:none;border-color:#FF512F!important}</style></head>
<body><div class="box">
  <h1>${title}</h1>
  ${msgHtml}
  ${formHtml}
</div></body></html>`;
}

// 获取用户 profile
app.get('/api/profile', authenticateToken, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT name, email FROM users WHERE id = $1',
      [req.user.user_id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.json({ success: true, name: result.rows[0].name || null, email: result.rows[0].email });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 获取用户的设备列表
app.get('/api/devices', authenticateToken, async (req, res) => {
  try {
    const isAdmin = req.user.username === 'admin';
    const result = isAdmin
      ? await db.query('SELECT * FROM devices ORDER BY created_at DESC')
      : await db.query('SELECT * FROM devices WHERE owner_id = $1 ORDER BY created_at DESC', [req.user.user_id]);
    
    // 补充实时状态
    const devices = await Promise.all(result.rows.map(async (device) => {
      const status = await redis.get(`device:${device.device_id}:status`);
      if (status) {
        device.realtime_status = JSON.parse(status);
      }
      return device;
    }));
    
    res.json({ devices });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 添加设备
app.post('/api/devices', authenticateToken, async (req, res) => {
  try {
    const { device_id, name } = req.body;
    
    const result = await db.query(
      `INSERT INTO devices (device_id, owner_id, name)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [device_id, req.user.user_id, name]
    );
    
    res.json({ success: true, device: result.rows[0] });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// 控制设备
app.post('/api/devices/:device_id/control', authenticateToken, async (req, res) => {
  try {
    const { device_id } = req.params;
    const { action, level } = req.body;

    // 验证设备所有权（admin可控制所有设备）
    const isAdmin = req.user.username === 'admin';
    const device = isAdmin
      ? await db.query('SELECT * FROM devices WHERE device_id = $1', [device_id])
      : await db.query('SELECT * FROM devices WHERE device_id = $1 AND owner_id = $2', [device_id, req.user.user_id]);

    if (device.rows.length === 0) {
      return res.status(404).json({ error: '设备不存在或无权限' });
    }

    // 发送 MQTT 控制指令
    const topic = `device/${device_id}/control`;
    const payloadObj = {
      action: action,
      timestamp: Date.now()
    };

    // 🔥 如果是LED档位控制，添加level参数 🔥
    if (action === 'led_level' && level !== undefined) {
      payloadObj.level = level;
    }

    // 🔥 如果是设置time或temp，添加value参数 🔥
    const { value } = req.body;
    if ((action === 'set_time' || action === 'set_temp') && value !== undefined) {
      payloadObj.value = value;
    }

    const payload = JSON.stringify(payloadObj);

    mqttClient.publish(topic, payload, { qos: 1 });

    // 记录日志（包含level/value信息）
    let logAction = action;
    if (action === 'led_level') {
      logAction = `led_level:${level}`;
    } else if (action === 'set_time' || action === 'set_temp') {
      logAction = `${action}:${value}`;
    }
    await db.query(
      `INSERT INTO control_logs (device_id, user_id, action, result)
       VALUES ($1, $2, $3, $4)`,
      [device_id, req.user.user_id, logAction, 'sent']
    );

    res.json({ success: true, message: '控制指令已发送' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 获取设备历史数据
app.get('/api/devices/:device_id/data', authenticateToken, async (req, res) => {
  try {
    const { device_id } = req.params;
    const { start_time, end_time, limit = 100 } = req.query;
    
    let query = `
      SELECT * FROM device_data 
      WHERE device_id = $1
    `;
    const params = [device_id];
    
    if (start_time) {
      params.push(start_time);
      query += ` AND created_at >= $${params.length}`;
    }
    
    if (end_time) {
      params.push(end_time);
      query += ` AND created_at <= $${params.length}`;
    }
    
    query += ` ORDER BY created_at DESC LIMIT $${params.length + 1}`;
    params.push(limit);
    
    const result = await db.query(query, params);
    
    res.json({ data: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 获取控制日志
app.get('/api/devices/:device_id/logs', authenticateToken, async (req, res) => {
  try {
    const { device_id } = req.params;
    const { limit = 50 } = req.query;
    
    const result = await db.query(
      `SELECT cl.*, u.username 
       FROM control_logs cl
       JOIN users u ON cl.user_id = u.id
       WHERE cl.device_id = $1
       ORDER BY cl.created_at DESC
       LIMIT $2`,
      [device_id, limit]
    );
    
    res.json({ logs: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 🔥 删除设备
app.delete('/api/devices/:device_id', authenticateToken, async (req, res) => {
  try {
    const { device_id } = req.params;
    
    // 验证设备所有权（admin可删除所有设备）
    const isAdmin = req.user.username === 'admin';
    const device = isAdmin
      ? await db.query('SELECT * FROM devices WHERE device_id = $1', [device_id])
      : await db.query('SELECT * FROM devices WHERE device_id = $1 AND owner_id = $2', [device_id, req.user.user_id]);

    if (device.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: '设备不存在或无权限'
      });
    }

    // 删除设备相关的所有数据
    // 1. 删除控制日志
    await db.query('DELETE FROM control_logs WHERE device_id = $1', [device_id]);
    
    // 2. 删除设备数据
    await db.query('DELETE FROM device_data WHERE device_id = $1', [device_id]);
    
    // 3. 删除设备记录
    await db.query('DELETE FROM devices WHERE device_id = $1', [device_id]);
    
    // 4. 清除 Redis 缓存
    await redis.del(`device:${device_id}:status`);
    
    console.log(`✓ 设备已删除: ${device_id}`);
    
    res.json({ 
      success: true, 
      message: '设备删除成功' 
    });
    
  } catch (error) {
    console.error('删除设备失败:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// ==================== 🔥 新增的3个OTA接口 🔥 ====================

// 1️⃣ 获取固件信息
app.get('/api/firmware/info', authenticateToken, (req, res) => {
  const firmwarePath = path.join(__dirname, 'uploads', 'firmware.bin');
  
  if (fs.existsSync(firmwarePath)) {
    const stats = fs.statSync(firmwarePath);
    const uploadTime = new Date(stats.mtime).toLocaleString('zh-CN');
    
    res.json({
      success: true,
      exists: true,
      size: stats.size,
      upload_time: uploadTime
    });
  } else {
    res.json({
      success: true,
      exists: false
    });
  }
});

// 2️⃣ 上传固件（覆盖 firmware.bin）
app.post('/api/firmware/upload', authenticateToken, upload.single('file'), async (req, res) => {
  try {
    // 🔥 权限检查：只有admin可以上传固件 🔥
    const username = req.user.username;
    if (username !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        error: '权限不足，只有管理员(admin)可以上传固件' 
      });
    }
    
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        error: '没有上传文件' 
      });
    }
    
    console.log(`✓ 固件已上传: ${req.file.filename}, 大小: ${req.file.size} bytes (上传者: ${username})`);
    
    res.json({
      success: true,
      message: '固件上传成功',
      filename: 'firmware.bin',
      size: req.file.size
    });
    
  } catch (error) {
    console.error('上传固件失败:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// 3️⃣ 触发OTA升级
app.post('/api/ota/trigger', authenticateToken, async (req, res) => {
  try {
    const { device_id } = req.body;
    
    if (!device_id) {
      return res.status(400).json({ 
        success: false, 
        error: '缺少设备ID' 
      });
    }
    
    // 检查固件是否存在
    const firmwarePath = path.join(__dirname, 'uploads', 'firmware.bin');
    if (!fs.existsSync(firmwarePath)) {
      return res.status(404).json({ 
        success: false, 
        error: '服务器上没有 firmware.bin 文件，请先上传' 
      });
    }
    
    // 验证设备所有权（admin可操作所有设备）
    const isAdmin = req.user.username === 'admin';
    const device = isAdmin
      ? await db.query('SELECT * FROM devices WHERE device_id = $1', [device_id])
      : await db.query('SELECT * FROM devices WHERE device_id = $1 AND owner_id = $2', [device_id, req.user.user_id]);

    if (device.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: '设备不存在或无权限'
      });
    }

    // 🔥 固定的固件URL
    const firmwareUrl = 'http://43.138.237.99/firmware/firmware.bin';
    
    // 发送 MQTT OTA 指令
    const topic = `device/${device_id}/ota`;
    const payload = JSON.stringify({
      url: firmwareUrl,
      timestamp: Date.now()
    });
    
    mqttClient.publish(topic, payload, { qos: 1 });
    
    console.log(`✓ OTA指令已发送到设备: ${device_id}`);
    console.log(`  固件URL: ${firmwareUrl}`);
    
    // 记录日志
    await db.query(
      `INSERT INTO control_logs (device_id, user_id, action, result)
       VALUES ($1, $2, $3, $4)`,
      [device_id, req.user.user_id, 'OTA_UPGRADE', 'sent']
    );
    
    res.json({ 
      success: true, 
      message: 'OTA指令已发送',
      firmware_url: firmwareUrl
    });
    
  } catch (error) {
    console.error('触发OTA失败:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// ==================== SD Card 远程更新接口 ====================

// 上传 SD 卡文件包 (sdcard.tar)
app.post('/api/sdcard/upload', authenticateToken, sdcardUpload.single('file'), async (req, res) => {
  try {
    const username = req.user.username;
    if (username !== 'admin') {
      return res.status(403).json({ success: false, error: '权限不足，只有管理员可以上传' });
    }

    if (!req.file) {
      return res.status(400).json({ success: false, error: '没有上传文件' });
    }

    console.log(`SD card package uploaded: ${req.file.size} bytes (by ${username})`);
    res.json({ success: true, message: 'SD卡文件包上传成功', size: req.file.size });
  } catch (error) {
    console.error('SD card upload failed:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// 获取 SD 卡文件包信息
app.get('/api/sdcard/info', authenticateToken, (req, res) => {
  const tarPath = path.join(__dirname, 'uploads', 'sdcard.tar');
  if (fs.existsSync(tarPath)) {
    const stats = fs.statSync(tarPath);
    res.json({
      success: true,
      exists: true,
      size: stats.size,
      upload_time: new Date(stats.mtime).toLocaleString('zh-CN')
    });
  } else {
    res.json({ success: true, exists: false });
  }
});

// 触发 SD 卡更新 (支持单设备或全部设备)
app.post('/api/sdcard/trigger', authenticateToken, async (req, res) => {
  try {
    const tarPath = path.join(__dirname, 'uploads', 'sdcard.tar');
    if (!fs.existsSync(tarPath)) {
      return res.status(404).json({ success: false, error: '服务器上没有 sdcard.tar，请先上传' });
    }

    const sdcardUrl = 'http://43.138.237.99/firmware/sdcard.tar';
    const { device_id } = req.body;

    if (device_id) {
      // 单设备更新
      const topic = `device/${device_id}/sdcard`;
      const payload = JSON.stringify({ url: sdcardUrl, timestamp: Date.now() });
      mqttClient.publish(topic, payload, { qos: 1 });
      console.log(`SD update command sent to device: ${device_id}`);

      await db.query(
        `INSERT INTO control_logs (device_id, user_id, action, result) VALUES ($1, $2, $3, $4)`,
        [device_id, req.user.user_id, 'SDCARD_UPDATE', 'sent']
      );

      res.json({ success: true, message: `SD卡更新指令已发送到 ${device_id}` });
    } else {
      // 全部设备更新 - 广播
      const topic = 'device/all/sdcard';
      const payload = JSON.stringify({ url: sdcardUrl, timestamp: Date.now() });
      mqttClient.publish(topic, payload, { qos: 1 });
      console.log('SD update command broadcast to ALL devices');
      res.json({ success: true, message: 'SD卡更新指令已广播到所有设备' });
    }
  } catch (error) {
    console.error('SD card trigger failed:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// ==================== SPIFFS OTA 接口 ====================

// 上传 spiffs.bin
app.post('/api/spiffs-ota/upload', authenticateToken, spiffsUpload.single('file'), async (req, res) => {
  try {
    if (req.user.username !== 'admin') {
      return res.status(403).json({ success: false, error: '权限不足，只有管理员可以上传' });
    }
    if (!req.file) {
      return res.status(400).json({ success: false, error: '没有上传文件' });
    }
    console.log(`✓ SPIFFS镜像已上传: ${req.file.size} bytes (by ${req.user.username})`);
    res.json({ success: true, message: 'SPIFFS镜像上传成功', size: req.file.size });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 获取 spiffs.bin 信息
app.get('/api/spiffs-ota/info', authenticateToken, (req, res) => {
  const filePath = path.join(__dirname, 'uploads', 'spiffs.bin');
  if (fs.existsSync(filePath)) {
    const stats = fs.statSync(filePath);
    res.json({
      success: true, exists: true,
      size: stats.size,
      upload_time: new Date(stats.mtime).toLocaleString('zh-CN')
    });
  } else {
    res.json({ success: true, exists: false });
  }
});

// 触发 SPIFFS OTA
app.post('/api/spiffs-ota/trigger', authenticateToken, async (req, res) => {
  try {
    const filePath = path.join(__dirname, 'uploads', 'spiffs.bin');
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, error: '服务器上没有 spiffs.bin，请先上传' });
    }

    const { device_id } = req.body;
    if (!device_id) {
      return res.status(400).json({ success: false, error: '缺少设备ID' });
    }

    const isAdmin = req.user.username === 'admin';
    const device = isAdmin
      ? await db.query('SELECT * FROM devices WHERE device_id = $1', [device_id])
      : await db.query('SELECT * FROM devices WHERE device_id = $1 AND owner_id = $2', [device_id, req.user.user_id]);

    if (device.rows.length === 0) {
      return res.status(404).json({ success: false, error: '设备不存在或无权限' });
    }

    const spiffsUrl = 'http://43.138.237.99/firmware/spiffs.bin';
    const topic = `device/${device_id}/spiffs_ota`;
    mqttClient.publish(topic, JSON.stringify({ url: spiffsUrl, timestamp: Date.now() }), { qos: 1 });

    await db.query(
      `INSERT INTO control_logs (device_id, user_id, action, result) VALUES ($1, $2, $3, $4)`,
      [device_id, req.user.user_id, 'SPIFFS_OTA', 'sent']
    );

    console.log(`✓ SPIFFS OTA指令已发送到设备: ${device_id}`);
    res.json({ success: true, message: 'SPIFFS OTA指令已发送', url: spiffsUrl });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// ==================== SPIFFS 单文件更新接口 ====================

// 上传单个文件（PNG/图片）
app.post('/api/spiffs-file/upload', authenticateToken, spiffsFileUpload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: '没有上传文件' });
    }
    console.log(`✓ SPIFFS单文件已上传: ${req.file.filename} (${req.file.size} bytes) by ${req.user.username}`);
    res.json({
      success: true,
      message: '文件上传成功',
      filename: req.file.filename,
      size: req.file.size,
      url: `http://43.138.237.99/firmware/spiffs_files/${req.file.filename}`
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 获取已上传的单文件列表
app.get('/api/spiffs-file/list', authenticateToken, (req, res) => {
  const dir = path.join(__dirname, 'uploads/spiffs_files');
  if (!fs.existsSync(dir)) {
    return res.json({ success: true, files: [] });
  }
  const files = fs.readdirSync(dir).map(name => {
    const stats = fs.statSync(path.join(dir, name));
    return {
      filename: name,
      size: stats.size,
      upload_time: new Date(stats.mtime).toLocaleString('zh-CN'),
      url: `http://43.138.237.99/firmware/spiffs_files/${name}`
    };
  });
  res.json({ success: true, files });
});

// 触发单文件更新（发 MQTT 给设备）
app.post('/api/spiffs-file/trigger', authenticateToken, async (req, res) => {
  try {
    const { device_id, filename, spiffs_path } = req.body;
    if (!device_id || !filename || !spiffs_path) {
      return res.status(400).json({ success: false, error: '缺少参数: device_id, filename, spiffs_path' });
    }

    const filePath = path.join(__dirname, 'uploads/spiffs_files', filename);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ success: false, error: `文件 ${filename} 不存在，请先上传` });
    }

    const isAdmin = req.user.username === 'admin';
    const device = isAdmin
      ? await db.query('SELECT * FROM devices WHERE device_id = $1', [device_id])
      : await db.query('SELECT * FROM devices WHERE device_id = $1 AND owner_id = $2', [device_id, req.user.user_id]);

    if (device.rows.length === 0) {
      return res.status(404).json({ success: false, error: '设备不存在或无权限' });
    }

    const fileUrl = `http://43.138.237.99/firmware/spiffs_files/${filename}`;
    const topic = `device/${device_id}/spiffs_file`;
    const payload = JSON.stringify({ url: fileUrl, path: spiffs_path, timestamp: Date.now() });
    mqttClient.publish(topic, payload, { qos: 1 });

    await db.query(
      `INSERT INTO control_logs (device_id, user_id, action, result) VALUES ($1, $2, $3, $4)`,
      [device_id, req.user.user_id, `SPIFFS_FILE:${spiffs_path}`, 'sent']
    );

    console.log(`✓ SPIFFS单文件更新指令已发送: ${device_id} <- ${fileUrl} -> ${spiffs_path}`);
    res.json({ success: true, message: '单文件更新指令已发送', url: fileUrl, path: spiffs_path });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// 屏保视频上传转换接口（视频 → GIF → gifsicle 压缩）
app.post('/api/screensaver/upload-convert', authenticateToken, screensaverVideoUpload.single('video'), async (req, res) => {
  const { execFile } = require('child_process');
  const { promisify } = require('util');
  const execFileAsync = promisify(execFile);

  if (!req.file) {
    return res.status(400).json({ success: false, error: '未收到视频文件' });
  }

  const inputPath = req.file.path;
  const tmpGifPath = path.join(__dirname, 'uploads/screensaver_tmp', `tmp_${Date.now()}.gif`);
  const outputDir = path.join(__dirname, 'uploads/spiffs_files');
  const outputPath = path.join(outputDir, 'screensaver_output.gif');

  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

  try {
    // 检查 ffmpeg 是否可用
    await execFileAsync('ffmpeg', ['-version']).catch(() => {
      throw new Error('ffmpeg 未安装，请先安装 ffmpeg');
    });

    // ffmpeg 两阶段 palettegen 转 GIF（320×352，≤5s，8fps，64色）
    // - fps=8：降低帧率减少解码压力
    // - max_colors=64：颜色减半，LZW 解压更快，文件更小
    // - stats_mode=diff：针对动画优化调色板
    // - diff_mode=rectangle：只更新变化区域，减小帧体积
    // - format=yuv420p：兼容 10-bit/ProRes/.mov 等格式
    await execFileAsync('ffmpeg', [
      '-i', inputPath,
      '-t', '30', // 最多处理前30秒，避免过长视频导致 GIF 过大
      '-vf', 'fps=8,scale=320:352:force_original_aspect_ratio=increase,crop=320:352,format=yuv420p,split[s0][s1];[s0]palettegen=max_colors=64:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle',
      '-y', tmpGifPath
    ]);

    // 检查 gifsicle 是否可用
    const hasGifsicle = await execFileAsync('gifsicle', ['--version']).then(() => true).catch(() => false);
    if (hasGifsicle) {
      await execFileAsync('gifsicle', ['-O3', '--lossy=80', '--colors', '64', tmpGifPath, '-o', outputPath]);
    } else {
      // gifsicle 不可用时直接使用 ffmpeg 输出
      fs.copyFileSync(tmpGifPath, outputPath);
      console.warn('⚠️ gifsicle 未安装，跳过有损压缩');
    }

    const stats = fs.statSync(outputPath);
    const url = `http://43.138.237.99/firmware/spiffs_files/screensaver_output.gif`;
    console.log(`✓ 屏保GIF转换完成: ${(stats.size / 1024).toFixed(1)}KB -> ${outputPath}`);
    res.json({ success: true, size: stats.size, url });
  } catch (err) {
    const detail = err.stderr ? err.stderr.slice(-800) : err.message;
    console.error('屏保转换失败:', detail);
    res.status(500).json({ success: false, error: detail });
  } finally {
    // 清理临时文件
    if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);
    if (fs.existsSync(tmpGifPath)) fs.unlinkSync(tmpGifPath);
  }
});

// multer 错误统一返回 JSON（防止 Express 默认返回 HTML 导致前端 JSON.parse 失败）
app.use((err, req, res, next) => {
  if (err && err.code && err.code.startsWith('LIMIT_')) {
    return res.status(400).json({ success: false, error: `文件上传错误: ${err.code}` });
  }
  if (err) {
    return res.status(500).json({ success: false, error: err.message || '服务器内部错误' });
  }
  next();
});

// ==================== ❌ 删除旧的OTA接口 ====================
// 把原来的这个删掉或注释掉：
/*
app.post('/api/ota/upload', authenticateToken, upload.single('file'), async (req, res) => {
    // ... 旧代码
});
*/

// ==================== WebSocket ====================
wss.on('connection', (ws, req) => {
  console.log('WebSocket 客户端已连接');
  
  ws.on('close', () => {
    console.log('WebSocket 客户端已断开');
  });
});

function broadcastToClients(data) {
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
}

// ==================== 启动服务器 ====================
async function startServer() {
  await initDatabase();
  
  const server = app.listen(PORT, () => {
    console.log(`✓ API 服务器运行在端口 ${PORT}`);
  });
  
  // WebSocket 升级
  server.on('upgrade', (request, socket, head) => {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  });
}

startServer();