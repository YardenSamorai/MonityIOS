const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const PasswordResetToken = sequelize.define('PasswordResetToken', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  codeHash: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  resetToken: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  expiresAt: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  attempts: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  verified: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  used: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
}, {
  indexes: [
    { fields: ['email'] },
    { fields: ['reset_token'] },
  ],
});

module.exports = PasswordResetToken;
