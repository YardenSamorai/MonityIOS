const cron = require('node-cron');
const { RecurringRule, Transaction, CreditCard, User } = require('../models');
const { Op } = require('sequelize');
const sequelize = require('../config/database');

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

function getAllMissedDates(rule, today) {
  const dates = [];
  const start = parseDate(rule.startDate);
  const end = rule.endDate ? parseDate(rule.endDate) : null;

  let cursor;
  if (rule.lastGenerated) {
    cursor = parseDate(rule.lastGenerated);
    cursor.setDate(cursor.getDate() + 1);
  } else {
    cursor = new Date(start);
  }

  if (cursor < start) cursor = new Date(start);

  let safety = 0;
  while (cursor <= today && safety < 400) {
    if (end && cursor > end) break;

    let isOccurrence = false;
    switch (rule.frequency) {
      case 'daily':
        isOccurrence = true;
        break;
      case 'weekly':
        isOccurrence = cursor.getDay() === start.getDay();
        break;
      case 'monthly': {
        const lastDay = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0).getDate();
        const targetDay = Math.min(start.getDate(), lastDay);
        isOccurrence = cursor.getDate() === targetDay;
        break;
      }
      case 'yearly':
        isOccurrence = cursor.getMonth() === start.getMonth() && cursor.getDate() === start.getDate();
        break;
    }

    if (isOccurrence) {
      dates.push(toLocalDateStr(cursor));
    }

    cursor.setDate(cursor.getDate() + 1);
    safety++;
  }

  return dates;
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
      const missedDates = getAllMissedDates(rule, today);

      if (missedDates.length === 0) continue;

      try {
        await sequelize.transaction(async (t) => {
          for (const dateStr of missedDates) {
            await Transaction.create({
              amount: rule.amount,
              currency: rule.currency,
              type: rule.type,
              note: rule.note,
              date: dateStr,
              categoryId: rule.categoryId,
              userId: rule.userId,
              recurringRuleId: rule.id,
            }, { transaction: t });
            created++;
            console.log(`Recurring: created ${rule.type} "${rule.note}" ${rule.amount} for ${dateStr}`);
          }

          rule.lastGenerated = missedDates[missedDates.length - 1];
          await rule.save({ transaction: t });
        });
      } catch (err) {
        console.error(`Failed to process rule ${rule.id}:`, err);
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

      try {
        await sequelize.transaction(async (t) => {
          const unbilledTxns = await Transaction.findAll({
            where: { creditCardId: card.id, isBilled: false },
            attributes: ['type', 'amount', 'currency'],
            transaction: t,
          });

          if (unbilledTxns.length === 0) {
            card.lastBilledAt = todayStr;
            await card.save({ transaction: t });
            return;
          }

          const currencyTotals = {};
          for (const txn of unbilledTxns) {
            const cur = txn.currency || 'ILS';
            const amt = parseFloat(txn.amount);
            if (!currencyTotals[cur]) currencyTotals[cur] = 0;
            currencyTotals[cur] += txn.type === 'expense' ? amt : -amt;
          }

          const user = await User.findByPk(card.userId, { attributes: ['preferredCurrency'], transaction: t });
          let billingCurrency = user?.preferredCurrency || 'ILS';
          const currenciesUsed = Object.keys(currencyTotals);
          if (currenciesUsed.length === 1) {
            billingCurrency = currenciesUsed[0];
          }

          const totalCharge = currencyTotals[billingCurrency] || 0;

          await Transaction.update(
            { isBilled: true },
            { where: { creditCardId: card.id, isBilled: false }, transaction: t }
          );

          if (totalCharge !== 0) {
            await Transaction.create({
              amount: Math.abs(totalCharge),
              currency: billingCurrency,
              type: totalCharge >= 0 ? 'expense' : 'income',
              note: `חיוב כרטיס ${card.name} ${card.lastFourDigits ? `(${card.lastFourDigits})` : ''}`.trim(),
              date: todayStr,
              userId: card.userId,
              creditCardId: null,
              isBilled: true,
            }, { transaction: t });
          }

          card.lastBilledAt = todayStr;
          await card.save({ transaction: t });
          billed++;
          console.log(`Credit card "${card.name}" billed ${totalCharge.toFixed(2)} ${billingCurrency} on ${todayStr}`);
        });
      } catch (err) {
        console.error(`Failed to bill card ${card.id}:`, err);
      }
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
