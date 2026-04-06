const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Category = sequelize.define('Category', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  nameHe: {
    type: DataTypes.STRING,
    defaultValue: '',
  },
  icon: {
    type: DataTypes.STRING,
    defaultValue: '💰',
  },
  color: {
    type: DataTypes.STRING(7),
    defaultValue: '#007AFF',
  },
  type: {
    type: DataTypes.ENUM('expense', 'income', 'both'),
    defaultValue: 'expense',
  },
  isDefault: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
});

module.exports = Category;
