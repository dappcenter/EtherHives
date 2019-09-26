const Migrations = artifacts.require('./Migrations.sol');
const BeeBee = artifacts.require('./BeeBee.sol');

module.exports = function (deployer) {
    deployer.deploy(Migrations);
    deployer.deploy(BeeBee);
};
