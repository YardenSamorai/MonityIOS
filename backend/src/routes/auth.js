const express = require('express');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const {
  User, HouseholdMember, Household, PasswordResetToken,
  Transaction, Budget, RecurringRule, CreditCard, Category,
} = require('../models');
const { generateToken, authMiddleware } = require('../middleware/auth');
const { seedDefaultCategories } = require('../seeders/defaultCategories');
const { sendOtpEmail } = require('../services/emailService');

const router = express.Router();

const OTP_EXPIRY_MINUTES = 15;
const OTP_MAX_ATTEMPTS = 5;
const RESET_TOKEN_EXPIRY_MINUTES = 15;
const FORGOT_RATE_LIMIT_MINUTES = 1;

function generateOtpCode() {
  const buf = crypto.randomBytes(4).readUInt32BE(0);
  const code = (buf % 1000000).toString().padStart(6, '0');
  return code;
}

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function isExpired(date) {
  return new Date() > new Date(date);
}

router.post('/register', async (req, res) => {
  try {
    const { email, password, name, preferredCurrency, locale } = req.body;

    if (!email || !password || !name) {
      return res.status(400).json({ error: 'Email, password, and name are required' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await User.findOne({ where: { email: email.toLowerCase() } });
    if (existing) {
      return res.status(409).json({ error: 'Email already registered' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const user = await User.create({
      email: email.toLowerCase(),
      passwordHash,
      name,
      preferredCurrency: preferredCurrency || 'ILS',
      locale: locale || 'he',
    });

    await seedDefaultCategories(user.id);

    await HouseholdMember.update(
      { userId: user.id },
      { where: { invitedEmail: email.toLowerCase(), status: 'pending', userId: null } }
    );

    const token = generateToken(user.id);
    res.status(201).json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        preferredCurrency: user.preferredCurrency,
        locale: user.locale,
        onboardingCompleted: user.onboardingCompleted,
      },
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const user = await User.findOne({ where: { email: email.toLowerCase() } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const { Category } = require('../models');
    const catCount = await Category.count({ where: { userId: user.id } });
    if (catCount === 0) {
      await seedDefaultCategories(user.id);
    }

    await HouseholdMember.update(
      { userId: user.id },
      { where: { invitedEmail: user.email, status: 'pending', userId: null } }
    );

    const pendingCount = await HouseholdMember.count({
      where: {
        status: 'pending',
        [require('sequelize').Op.or]: [
          { userId: user.id },
          { invitedEmail: user.email },
        ],
      },
    });

    const token = generateToken(user.id);
    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        preferredCurrency: user.preferredCurrency,
        locale: user.locale,
        onboardingCompleted: user.onboardingCompleted,
      },
      pendingInvitations: pendingCount,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

router.post('/forgot-password', async (req, res) => {
  try {
    const { email, locale } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = String(email).toLowerCase().trim();
    const language = (locale === 'en' || locale === 'he') ? locale : 'he';

    const genericResponse = { message: 'If an account exists for this email, a code has been sent.' };

    const user = await User.findOne({ where: { email: normalizedEmail } });
    if (!user) {
      return res.json(genericResponse);
    }

    const recent = await PasswordResetToken.findOne({
      where: {
        email: normalizedEmail,
        createdAt: { [Op.gte]: new Date(Date.now() - FORGOT_RATE_LIMIT_MINUTES * 60 * 1000) },
        used: false,
      },
      order: [['createdAt', 'DESC']],
    });
    if (recent) {
      return res.status(429).json({
        error: 'Please wait a moment before requesting another code.',
      });
    }

    await PasswordResetToken.update(
      { used: true },
      { where: { userId: user.id, used: false } }
    );

    const code = generateOtpCode();
    const codeHash = hashCode(code);
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    await PasswordResetToken.create({
      userId: user.id,
      email: normalizedEmail,
      codeHash,
      expiresAt,
    });

    await sendOtpEmail(normalizedEmail, code, language);

    return res.json(genericResponse);
  } catch (err) {
    console.error('Forgot password error:', err);
    res.status(500).json({ error: 'Failed to process request' });
  }
});

router.post('/verify-otp', async (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ error: 'Email and code are required' });
    }

    const normalizedEmail = String(email).toLowerCase().trim();
    const codeStr = String(code).trim();

    const tokenRecord = await PasswordResetToken.findOne({
      where: { email: normalizedEmail, used: false, verified: false },
      order: [['createdAt', 'DESC']],
    });

    if (!tokenRecord) {
      return res.status(400).json({ error: 'Invalid or expired code. Please request a new one.' });
    }

    if (isExpired(tokenRecord.expiresAt)) {
      tokenRecord.used = true;
      await tokenRecord.save();
      return res.status(400).json({ error: 'Code has expired. Please request a new one.' });
    }

    if (tokenRecord.attempts >= OTP_MAX_ATTEMPTS) {
      tokenRecord.used = true;
      await tokenRecord.save();
      return res.status(429).json({ error: 'Too many attempts. Please request a new code.' });
    }

    const expectedHash = hashCode(codeStr);
    if (expectedHash !== tokenRecord.codeHash) {
      tokenRecord.attempts += 1;
      await tokenRecord.save();
      return res.status(400).json({ error: 'Invalid code.' });
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    tokenRecord.resetToken = resetToken;
    tokenRecord.verified = true;
    tokenRecord.expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRY_MINUTES * 60 * 1000);
    await tokenRecord.save();

    return res.json({ resetToken });
  } catch (err) {
    console.error('Verify OTP error:', err);
    res.status(500).json({ error: 'Failed to verify code' });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const { email, resetToken, newPassword } = req.body;

    if (!email || !resetToken || !newPassword) {
      return res.status(400).json({ error: 'Email, reset token, and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const normalizedEmail = String(email).toLowerCase().trim();

    const tokenRecord = await PasswordResetToken.findOne({
      where: {
        email: normalizedEmail,
        resetToken,
        verified: true,
        used: false,
      },
    });

    if (!tokenRecord) {
      return res.status(400).json({ error: 'Invalid or expired reset session.' });
    }

    if (isExpired(tokenRecord.expiresAt)) {
      tokenRecord.used = true;
      await tokenRecord.save();
      return res.status(400).json({ error: 'Reset session expired. Please start over.' });
    }

    const user = await User.findByPk(tokenRecord.userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();

    tokenRecord.used = true;
    await tokenRecord.save();

    await PasswordResetToken.update(
      { used: true },
      { where: { userId: user.id, used: false } }
    );

    res.json({ message: 'Password reset successfully' });
  } catch (err) {
    console.error('Reset password error:', err);
    res.status(500).json({ error: 'Password reset failed' });
  }
});

router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await User.findByPk(req.userId, {
      attributes: ['id', 'email', 'name', 'preferredCurrency', 'locale', 'onboardingCompleted'],
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ user });
  } catch (err) {
    console.error('Me error:', err);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

router.post('/reset-account', authMiddleware, async (req, res) => {
  const t = await sequelize.transaction();
  try {
    const userId = req.userId;

    const membership = await HouseholdMember.findOne({
      where: { userId, status: 'active' },
      transaction: t,
    });
    if (membership) {
      const householdId = membership.householdId;
      if (membership.role === 'owner') {
        await HouseholdMember.destroy({ where: { householdId }, transaction: t });
        await Household.destroy({ where: { id: householdId }, transaction: t });
      } else {
        await membership.destroy({ transaction: t });
      }
    }

    await Transaction.destroy({ where: { userId }, transaction: t });
    await Budget.destroy({ where: { userId }, transaction: t });
    await RecurringRule.destroy({ where: { userId }, transaction: t });
    await CreditCard.destroy({ where: { userId }, transaction: t });
    await Category.destroy({ where: { userId }, transaction: t });
    await PasswordResetToken.destroy({ where: { userId }, transaction: t });

    await t.commit();
    await seedDefaultCategories(userId);

    res.json({ success: true });
  } catch (err) {
    await t.rollback();
    console.error('Reset account error:', err);
    res.status(500).json({ error: 'Failed to reset account' });
  }
});

router.put('/me', authMiddleware, async (req, res) => {
  try {
    const { name, preferredCurrency, locale } = req.body;
    const user = await User.findByPk(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    if (name) user.name = name;
    if (preferredCurrency) user.preferredCurrency = preferredCurrency;
    if (locale) user.locale = locale;
    if (req.body.onboardingCompleted !== undefined) user.onboardingCompleted = req.body.onboardingCompleted;
    await user.save();

    res.json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        preferredCurrency: user.preferredCurrency,
        locale: user.locale,
        onboardingCompleted: user.onboardingCompleted,
      },
    });
  } catch (err) {
    console.error('Update user error:', err);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

module.exports = router;
