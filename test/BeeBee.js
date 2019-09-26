// const { expectRevert } = require('openzeppelin-test-helpers');
// const { expect } = require('chai');

const BeeBee = artifacts.require('BeeBee');

contract('BeeBee', function ([_, addr1]) {
    describe('BeeBee', async function () {
        it('should be ok', async function () {
            this.token = await BeeBee.new();
        });
    });
});
