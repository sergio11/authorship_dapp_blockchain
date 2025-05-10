const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const secret = require('../../.secret.json');

module.exports = buildModule("AuthorshipDApp", (m) => {
    const rewardToken = m.contract("RewardToken", [secret.ownerKey]);
    const authorshipDApp = m.contract("AuthorshipDApp", [secret.ownerKey, rewardToken]);
    return { rewardToken, authorshipDApp };
});