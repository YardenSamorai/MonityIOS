/**
 * Normalizes recurring rule startDate so the first generated occurrence is never
 * "backfilled" before today — aligns with UX where past dates in the month mean
 * "wait until the same calendar day next month" (for monthly salary/bills).
 */

function toLocalDateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function startOfToday() {
  const t = new Date();
  t.setHours(0, 0, 0, 0);
  return t;
}

function parseLocal(str) {
  const [y, mo, d] = str.split('-').map(Number);
  const x = new Date(y, mo - 1, d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function normalizeMonthly(startDateStr) {
  const [y, m, d] = startDateStr.split('-').map(Number);
  const targetDay = d;
  const today = startOfToday();

  let cur = new Date(y, m - 1, 1);
  for (let i = 0; i < 600; i += 1) {
    const lastDay = new Date(cur.getFullYear(), cur.getMonth() + 1, 0).getDate();
    const dom = Math.min(targetDay, lastDay);
    const candidate = new Date(cur.getFullYear(), cur.getMonth(), dom);
    if (candidate >= today) return toLocalDateStr(candidate);
    cur.setMonth(cur.getMonth() + 1);
    cur.setDate(1);
  }
  return startDateStr;
}

function normalizeWeekly(startDateStr) {
  const today = startOfToday();
  const start = parseLocal(startDateStr);
  if (start >= today) return startDateStr;

  const targetWeekday = start.getDay();
  const cursor = new Date(today);
  for (let i = 0; i < 7; i += 1) {
    if (cursor.getDay() === targetWeekday) return toLocalDateStr(cursor);
    cursor.setDate(cursor.getDate() + 1);
  }
  return startDateStr;
}

function normalizeDaily(startDateStr) {
  const today = startOfToday();
  const start = parseLocal(startDateStr);
  if (start >= today) return startDateStr;
  return toLocalDateStr(today);
}

function normalizeYearly(startDateStr) {
  const today = startOfToday();
  const start = parseLocal(startDateStr);
  if (start >= today) return startDateStr;

  let ny = start.getFullYear() + 1;
  const nm = start.getMonth();
  const nd = start.getDate();
  const lastDay = new Date(ny, nm + 1, 0).getDate();
  const dom = Math.min(nd, lastDay);
  return toLocalDateStr(new Date(ny, nm, dom));
}

function normalizeRecurringStartDate(frequency, startDateStr) {
  if (!startDateStr || typeof startDateStr !== 'string') return startDateStr;
  const parts = startDateStr.split('-');
  if (parts.length !== 3) return startDateStr;

  switch (frequency) {
    case 'monthly':
      return normalizeMonthly(startDateStr);
    case 'weekly':
      return normalizeWeekly(startDateStr);
    case 'daily':
      return normalizeDaily(startDateStr);
    case 'yearly':
      return normalizeYearly(startDateStr);
    default:
      return startDateStr;
  }
}

module.exports = { normalizeRecurringStartDate, toLocalDateStr };
