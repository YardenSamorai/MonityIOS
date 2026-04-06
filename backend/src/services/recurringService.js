const cron = require('node-cron');
const { RecurringRule, Transaction, CreditCard } = require('../models');
const { Op } = require('sequelize');

function toLocalDateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function parseDate(str) {
  const [y, m, d] = str.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function shouldGenerateToday(rule, today) {
  const start = parseDate(rule.startDate);
  if (today < start) return false;
  if (rule.endDate && today > parseDate(rule.endDate)) return false;

  const startDay = start.getDate();
  const startDayOfWeek = start.getDay();
  const todayDay = today.getDate();
  const todayDayOfWeek = today.getDay();
  const todayStr = toLocalDateStr(today);

  if (rule.lastGenerated === todayStr) return false;

  switch (rule.frequency) {
    case 'daily':
      return true;

    case 'weekly':
      return todayDayOfWeek === startDayOfWeek;

    case 'monthly': {
      const lastDayOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
      const targetDay = Math.min(startDay, lastDayOfMonth);
      return todayDay === targetDay;
    }

    case 'yearly': {
      return today.getMonth() === start.getMonth() && todayDay === startDay;
    }

    default:
      return false;
  }
}

function getMissedDate(rule, today) {
  const start = parseDate(rule.startDate);
  if (today < start) return null;
  if (rule.endDate && today > parseDate(rule.endDate)) return null;

  const todayStr = toLocalDateStr(today);
  const currentMonth = todayStr.substring(0, 7);

  const lastGen = rule.lastGenerated;
  const lastGenMonth = lastGen ? lastGen.substring(0, 7) : null;

  switch (rule.frequency) {
    case 'daily': {
      if (lastGen === todayStr) return null;
      return todayStr;
    }

    case 'weekly': {
      const startDayOfWeek = start.getDay();
      const todayDayOfWeek = today.getDay();
      if (todayDayOfWeek === startDayOfWeek && lastGen !== todayStr) return todayStr;
      if (!lastGen || daysBetween(lastGen, todayStr) >= 7) {
        let d = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        d.setDate(d.getDate() - ((todayDayOfWeek - startDayOfWeek + 7) % 7));
        const missedStr = toLocalDateStr(d);
        if (missedStr !== lastGen && missedStr >= rule.startDate && missedStr <= todayStr) return missedStr;
      }
      return null;
    }

    case 'monthly': {
      if (lastGenMonth === currentMonth) return null;
      const lastDayOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
      const targetDay = Math.min(start.getDate(), lastDayOfMonth);
      if (today.getDate() >= targetDay) {
        const missedDate = new Date(today.getFullYear(), today.getMonth(), targetDay);
        const missedStr = toLocalDateStr(missedDate);
        if (missedStr >= rule.startDate) return missedStr;
      }
      return null;
    }

    case 'yearly': {
      const currentYear = String(today.getFullYear());
      const lastGenYear = lastGen ? lastGen.substring(0, 4) : null;
      if (lastGenYear === currentYear) return null;
      if (today.getMonth() > start.getMonth() ||
          (today.getMonth() === start.getMonth() && today.getDate() >= start.getDate())) {
        const missedDate = new Date(today.getFullYear(), start.getMonth(), start.getDate());
        const missedStr = toLocalDateStr(missedDate);
        if (missedStr >= rule.startDate) return missedStr;
      }
      return null;
    }

    default:
      return null;
  }
}

function daysBetween(dateStr1, dateStr2) {
  const d1 = new Date(dateStr1);
  const d2 = new Date(dateStr2);
  return Math.floor((d2 - d1) / (1000 * 60 * 60 * 24));
}

async function processRecurringRules() {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStr = toLocalDateStr(today);

    const rules = await RecurringRule.findAll({
      where: {
        isActive: true,
        startDate: { [Op.lte]: todayStr },
        [Op.or]: [
          { endDate: null },
          { endDate: { [Op.gte]: todayStr } },
        ],
      },
    });

    let created = 0;
    for (const rule of rules) {
      let transactionDate = null;

      if (shouldGenerateToday(rule, today)) {
        transactionDate = todayStr;
      } else {
        transactionDate = getMissedDate(rule, today);
      }

      if (transactionDate) {
        await Transaction.create({
          amount: rule.amount,
          currency: rule.currency,
          type: rule.type,
          note: rule.note,
          date: transactionDate,
          categoryId: rule.categoryId,
          userId: rule.userId,
          recurringRuleId: rule.id,
        });

        rule.lastGenerated = todayStr;
        await rule.save();
        created++;
        console.log(`Recurring: created ${rule.type} "${rule.note}" ₪${rule.amount} for ${transactionDate}`);
      }
    }

    if (created > 0) {
      console.log(`Recurring: generated ${created} transactions`);
    }
  } catch (err) {
    console.error('Recurring job error:', err);
  }
}

async function processCreditCardBilling() {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayDay = today.getDate();
    const todayStr = toLocalDateStr(today);
    const currentMonth = todayStr.substring(0, 7);

    const cards = await CreditCard.findAll({
      where: {
        isActive: true,
        billingDay: todayDay,
      },
    });

    let billed = 0;
    for (const card of cards) {
      const lastBilledMonth = card.lastBilledAt
        ? (() => {
            const d = new Date(card.lastBilledAt);
            return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
          })()
        : null;

      if (lastBilledMonth === currentMonth) continue;

      const unbilledExpenses = await Transaction.sum('amount', {
        where: { creditCardId: card.id, isBilled: false, type: 'expense' },
      }) || 0;
      const unbilledCredits = await Transaction.sum('amount', {
        where: { creditCardId: card.id, isBilled: false, type: 'income' },
      }) || 0;
      const totalCharge = parseFloat(unbilledExpenses) - parseFloat(unbilledCredits);

      if (totalCharge <= 0) {
        card.lastBilledAt = todayStr;
        await card.save();
        continue;
      }

      await Transaction.update(
        { isBilled: true },
        { where: { creditCardId: card.id, isBilled: false } }
      );

      await Transaction.create({
        amount: totalCharge,
        currency: 'ILS',
        type: 'expense',
        note: `חיוב כרטיס ${card.name} ${card.lastFourDigits ? `(${card.lastFourDigits})` : ''}`.trim(),
        date: todayStr,
        userId: card.userId,
        creditCardId: null,
        isBilled: true,
      });

      card.lastBilledAt = todayStr;
      await card.save();
      billed++;

      console.log(`Credit card "${card.name}" billed ₪${totalCharge.toFixed(2)} on ${todayStr}`);
    }

    if (billed > 0) {
      console.log(`Credit cards: billed ${billed} cards on ${todayStr}`);
    }
  } catch (err) {
    console.error('Credit card billing error:', err);
  }
}

async function runAllScheduledJobs() {
  await processRecurringRules();
  await processCreditCardBilling();
}

function startRecurringJob() {
  cron.schedule('5 0 * * *', runAllScheduledJobs);
  console.log('Scheduled jobs registered (recurring transactions + credit card billing)');

  setTimeout(runAllScheduledJobs, 5000);
}

module.exports = { startRecurringJob, processRecurringRules, processCreditCardBilling };
