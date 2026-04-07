const express = require('express');
const bcrypt = require('bcryptjs');
const { User } = require('../models');
const { generateToken, authMiddleware } = require('../middleware/auth');
const { seedDefaultCategories } = require('../seeders/defaultCategories');

const router = express.Router();

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
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Login failed' });
  }
});

router.post('/reset-password', async (req, res) => {
  try {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
      return res.status(400).json({ error: 'Email and new password are required' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const user = await User.findOne({ where: { email: email.toLowerCase() } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();

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
