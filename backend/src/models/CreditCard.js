const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const CreditCard = sequelize.define('CreditCard', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  lastFourDigits: {
    type: DataTypes.STRING(4),
    defaultValue: '',
  },
  billingDay: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: { min: 1, max: 28 },
  },
  creditLimit: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: true,
  },
  color: {
    type: DataTypes.STRING(7),
    defaultValue: '#6C63FF',
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  lastBilledAt: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },
  sortOrder: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
});

module.exports = CreditCard;
