const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const HouseholdMember = sequelize.define('HouseholdMember', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  role: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'member',
  },
  status: {
    type: DataTypes.STRING,
    allowNull: false,
    defaultValue: 'pending',
  },
  invitedEmail: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  joinedAt: {
    type: DataTypes.DATE,
    allowNull: true,
  },
}, {
  tableName: 'household_members',
});

module.exports = HouseholdMember;
