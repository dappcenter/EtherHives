const Migrations = artifacts.require('./Migrations.sol');
const EtherHives = artifacts.require('./EtherHives.sol');

module.exports = function (deployer) {
    deployer.deploy(Migrations);
    deployer.deploy(EtherHives);
};
