const express = require('express');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const {
  User, Household, HouseholdMember,
  Transaction, Category, CreditCard, Budget, RecurringRule,
} = require('../models');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

async function getHouseholdMemberIds(userId) {
  const membership = await HouseholdMember.findOne({
    where: { userId, status: 'active' },
  });
  if (!membership) return null;

  const members = await HouseholdMember.findAll({
    where: { householdId: membership.householdId, status: 'active' },
  });
  return members.map(m => m.userId);
}

router.post('/', async (req, res) => {
  try {
    const existing = await HouseholdMember.findOne({
      where: { userId: req.userId, status: 'active' },
    });
    if (existing) {
      return res.status(409).json({ error: 'You already belong to a household' });
    }

    const { name } = req.body;
    const household = await Household.create({
      name: name || 'משק בית',
      createdBy: req.userId,
    });

    await HouseholdMember.create({
      householdId: household.id,
      userId: req.userId,
      role: 'owner',
      status: 'active',
      joinedAt: new Date(),
    });

    const full = await Household.findByPk(household.id, {
      include: [{
        model: HouseholdMember,
        include: [{ model: User, attributes: ['id', 'name', 'email'] }],
      }],
    });

    res.status(201).json({ household: full });
  } catch (err) {
    console.error('Create household error:', err);
    res.status(500).json({ error: 'Failed to create household' });
  }
});

router.get('/', async (req, res) => {
  try {
    const membership = await HouseholdMember.findOne({
      where: { userId: req.userId, status: 'active' },
    });
    if (!membership) {
      return res.json({ household: null });
    }

    const household = await Household.findByPk(membership.householdId, {
      include: [{
        model: HouseholdMember,
        include: [{ model: User, attributes: ['id', 'name', 'email'] }],
      }],
    });

    res.json({ household });
  } catch (err) {
    console.error('Get household error:', err);
    res.status(500).json({ error: 'Failed to fetch household' });
  }
});

router.post('/invite', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    const normalizedEmail = email.toLowerCase();

    if (normalizedEmail === (await User.findByPk(req.userId))?.email) {
      return res.status(400).json({ error: 'You cannot invite yourself' });
    }

    const membership = await HouseholdMember.findOne({
      where: { userId: req.userId, status: 'active' },
    });
    if (!membership) {
      return res.status(400).json({ error: 'You must create a household first' });
    }

    const existingInvite = await HouseholdMember.findOne({
      where: {
        householdId: membership.householdId,
        invitedEmail: normalizedEmail,
        status: 'pending',
      },
    });
    if (existingInvite) {
      return res.status(409).json({ error: 'Invitation already sent to this email' });
    }

    const activeMembers = await HouseholdMember.count({
      where: { householdId: membership.householdId, status: 'active' },
    });
    if (activeMembers >= 2) {
      return res.status(400).json({ error: 'Household already has 2 members' });
    }

    const invitedUser = await User.findOne({ where: { email: normalizedEmail } });

    if (invitedUser) {
      const alreadyInHousehold = await HouseholdMember.findOne({
        where: { userId: invitedUser.id, status: 'active' },
      });
      if (alreadyInHousehold) {
        return res.status(400).json({ error: 'This user already belongs to a household' });
      }
    }

    const invite = await HouseholdMember.create({
      householdId: membership.householdId,
      userId: invitedUser ? invitedUser.id : null,
      role: 'member',
      status: 'pending',
      invitedEmail: normalizedEmail,
    });

    res.status(201).json({ invitation: invite });
  } catch (err) {
    console.error('Invite error:', err);
    res.status(500).json({ error: 'Failed to send invitation' });
  }
});

router.get('/invitations', async (req, res) => {
  try {
    const user = await User.findByPk(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    const invitations = await HouseholdMember.findAll({
      where: {
        status: 'pending',
        [Op.or]: [
          { userId: req.userId },
          { invitedEmail: user.email },
        ],
      },
      include: [{
        model: Household,
        include: [{
          model: HouseholdMember,
          where: { role: 'owner', status: 'active' },
          include: [{ model: User, attributes: ['id', 'name', 'email'] }],
        }],
      }],
    });

    const formatted = invitations.map(inv => ({
      id: inv.id,
      householdId: inv.householdId,
      householdName: inv.Household?.name || 'משק בית',
      invitedByName: inv.Household?.HouseholdMembers?.[0]?.User?.name || '',
      invitedByEmail: inv.Household?.HouseholdMembers?.[0]?.User?.email || '',
      status: inv.status,
      createdAt: inv.createdAt,
    }));

    res.json({ invitations: formatted });
  } catch (err) {
    console.error('Get invitations error:', err);
    res.status(500).json({ error: 'Failed to fetch invitations' });
  }
});

router.post('/invitations/:id/accept', async (req, res) => {
  try {
    const invitation = await HouseholdMember.findByPk(req.params.id);
    if (!invitation || invitation.status !== 'pending') {
      return res.status(404).json({ error: 'Invitation not found' });
    }

    const user = await User.findByPk(req.userId);
    if (invitation.userId !== req.userId && invitation.invitedEmail !== user.email) {
      return res.status(403).json({ error: 'This invitation is not for you' });
    }

    const existingActive = await HouseholdMember.findOne({
      where: { userId: req.userId, status: 'active' },
    });
    if (existingActive) {
      return res.status(400).json({ error: 'You already belong to a household' });
    }

    invitation.userId = req.userId;
    invitation.status = 'active';
    invitation.joinedAt = new Date();
    await invitation.save();

    const household = await Household.findByPk(invitation.householdId, {
      include: [{
        model: HouseholdMember,
        include: [{ model: User, attributes: ['id', 'name', 'email'] }],
      }],
    });

    res.json({ household });
  } catch (err) {
    console.error('Accept invitation error:', err);
    res.status(500).json({ error: 'Failed to accept invitation' });
  }
});

router.post('/invitations/:id/decline', async (req, res) => {
  try {
    const invitation = await HouseholdMember.findByPk(req.params.id);
    if (!invitation || invitation.status !== 'pending') {
      return res.status(404).json({ error: 'Invitation not found' });
    }

    const user = await User.findByPk(req.userId);
    if (invitation.userId !== req.userId && invitation.invitedEmail !== user.email) {
      return res.status(403).json({ error: 'This invitation is not for you' });
    }

    invitation.status = 'declined';
    await invitation.save();

    res.json({ success: true });
  } catch (err) {
    console.error('Decline invitation error:', err);
    res.status(500).json({ error: 'Failed to decline invitation' });
  }
});

router.delete('/leave', async (req, res) => {
  try {
    const membership = await HouseholdMember.findOne({
      where: { userId: req.userId, status: 'active' },
    });
    if (!membership) {
      return res.status(404).json({ error: 'You are not in a household' });
    }

    const householdId = membership.householdId;

    if (membership.role === 'owner') {
      await HouseholdMember.destroy({ where: { householdId } });
      await Household.destroy({ where: { id: householdId } });
    } else {
      membership.status = 'declined';
      await membership.save();
    }

    res.json({ success: true });
  } catch (err) {
    console.error('Leave household error:', err);
    res.status(500).json({ error: 'Failed to leave household' });
  }
});

router.get('/summary', async (req, res) => {
  try {
    const memberIds = await getHouseholdMemberIds(req.userId);
    if (!memberIds) {
      return res.status(404).json({ error: 'No active household' });
    }

    const { from, to } = req.query;
    const where = { userId: { [Op.in]: memberIds } };
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const bankWhere = {
      ...where,
      [Op.or]: [{ creditCardId: null }, { isBilled: true }],
    };

    const income = await Transaction.sum('amount', { where: { ...bankWhere, type: 'income' } }) || 0;
    const expense = await Transaction.sum('amount', { where: { ...bankWhere, type: 'expense' } }) || 0;

    const byCategory = await Transaction.findAll({
      where: { ...where, type: 'expense' },
      attributes: [
        'categoryId',
        [sequelize.fn('SUM', sequelize.col('amount')), 'total'],
        [sequelize.fn('COUNT', sequelize.col('Transaction.id')), 'count'],
      ],
      include: [{ model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] }],
      group: ['categoryId', 'Category.id'],
      order: [[sequelize.fn('SUM', sequelize.col('amount')), 'DESC']],
    });

    const byMember = await Promise.all(memberIds.map(async (uid) => {
      const user = await User.findByPk(uid, { attributes: ['id', 'name'] });
      const memberIncome = await Transaction.sum('amount', {
        where: { ...bankWhere, userId: uid, type: 'income' },
      }) || 0;
      const memberExpense = await Transaction.sum('amount', {
        where: { ...bankWhere, userId: uid, type: 'expense' },
      }) || 0;
      return {
        userId: uid,
        name: user?.name || '',
        income: parseFloat(memberIncome),
        expense: parseFloat(memberExpense),
      };
    }));

    res.json({
      income: parseFloat(income),
      expense: parseFloat(expense),
      balance: parseFloat(income) - parseFloat(expense),
      byCategory,
      byMember,
    });
  } catch (err) {
    console.error('Household summary error:', err);
    res.status(500).json({ error: 'Failed to fetch household summary' });
  }
});

router.get('/transactions', async (req, res) => {
  try {
    const memberIds = await getHouseholdMemberIds(req.userId);
    if (!memberIds) {
      return res.status(404).json({ error: 'No active household' });
    }

    const { type, from, to, page = 1, limit = 50 } = req.query;
    const where = { userId: { [Op.in]: memberIds } };

    if (type) where.type = type;
    if (from || to) {
      where.date = {};
      if (from) where.date[Op.gte] = from;
      if (to) where.date[Op.lte] = to;
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: CreditCard, attributes: ['id', 'name', 'lastFourDigits', 'color'] },
        { model: User, attributes: ['id', 'name'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit: parseInt(limit),
      offset,
    });

    res.json({
      transactions: rows,
      total: count,
      page: parseInt(page),
      pages: Math.ceil(count / parseInt(limit)),
    });
  } catch (err) {
    console.error('Household transactions error:', err);
    res.status(500).json({ error: 'Failed to fetch household transactions' });
  }
});

router.get('/credit-cards', async (req, res) => {
  try {
    const memberIds = await getHouseholdMemberIds(req.userId);
    if (!memberIds) {
      return res.status(404).json({ error: 'No active household' });
    }

    const cards = await CreditCard.findAll({
      where: { userId: { [Op.in]: memberIds } },
      include: [{ model: User, attributes: ['id', 'name'] }],
      order: [['sortOrder', 'ASC'], ['createdAt', 'DESC']],
    });

    const cardsWithBalance = await Promise.all(
      cards.map(async (card) => {
        const unbilled = await Transaction.sum('amount', {
          where: { creditCardId: card.id, isBilled: false, type: 'expense' },
        }) || 0;
        const unbilledCredits = await Transaction.sum('amount', {
          where: { creditCardId: card.id, isBilled: false, type: 'income' },
        }) || 0;
        return {
          ...card.toJSON(),
          currentBalance: parseFloat(unbilled) - parseFloat(unbilledCredits),
        };
      })
    );

    res.json({ creditCards: cardsWithBalance });
  } catch (err) {
    console.error('Household credit cards error:', err);
    res.status(500).json({ error: 'Failed to fetch household credit cards' });
  }
});

router.get('/recurring', async (req, res) => {
  try {
    const memberIds = await getHouseholdMemberIds(req.userId);
    if (!memberIds) {
      return res.status(404).json({ error: 'No active household' });
    }

    const rules = await RecurringRule.findAll({
      where: { userId: { [Op.in]: memberIds } },
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: User, attributes: ['id', 'name'] },
      ],
      order: [['createdAt', 'DESC']],
    });

    res.json({ recurringRules: rules });
  } catch (err) {
    console.error('Household recurring error:', err);
    res.status(500).json({ error: 'Failed to fetch household recurring rules' });
  }
});

router.get('/budgets', async (req, res) => {
  try {
    const memberIds = await getHouseholdMemberIds(req.userId);
    if (!memberIds) {
      return res.status(404).json({ error: 'No active household' });
    }

    const budgets = await Budget.findAll({
      where: { userId: { [Op.in]: memberIds } },
      include: [
        { model: Category, attributes: ['id', 'name', 'nameHe', 'icon', 'color'] },
        { model: User, attributes: ['id', 'name'] },
      ],
    });

    res.json({ budgets });
  } catch (err) {
    console.error('Household budgets error:', err);
    res.status(500).json({ error: 'Failed to fetch household budgets' });
  }
});

module.exports = router;
