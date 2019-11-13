// const { expectRevert } = require('openzeppelin-test-helpers');
// const { expect } = require('chai');

const EtherHives = artifacts.require('EtherHives');

contract('EtherHives', function ([_, addr1]) {
    describe('EtherHives', async function () {
        it('should be ok', async function () {
            this.token = await EtherHives.new();
        });
    });
});
