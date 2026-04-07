const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Transaction = sequelize.define('Transaction', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
  },
  currency: {
    type: DataTypes.STRING(3),
    defaultValue: 'ILS',
  },
  type: {
    type: DataTypes.ENUM('expense', 'income'),
    allowNull: false,
  },
  note: {
    type: DataTypes.STRING(500),
    defaultValue: '',
  },
  date: {
    type: DataTypes.DATEONLY,
    allowNull: false,
    defaultValue: DataTypes.NOW,
  },
  isBilled: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  installmentNumber: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  installmentCount: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  installmentGroupId: {
    type: DataTypes.UUID,
    allowNull: true,
  },
});

module.exports = Transaction;
