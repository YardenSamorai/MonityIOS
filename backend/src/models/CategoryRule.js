const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const CategoryRule = sequelize.define('CategoryRule', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  pattern: {
    type: DataTypes.STRING(200),
    allowNull: false,
  },
  priority: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
});

module.exports = CategoryRule;
