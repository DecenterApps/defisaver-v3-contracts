const hre = require('hardhat');
const { redeploy } = require('../utils');
const {ethers} = require("hardhat");

describe('LiquityV2AdjustTimeTrigger', () => {
    let trigger;
    // ETH market
    const MARKET_ADDRESS = '0x38e1f07b954cfab7239d7acab49997fbaad96476';


    before(async () => {
        trigger = await redeploy('LiquityV2AdjustTimeTrigger');
    });

    it('should return false when current time <= lastInterestRateAdjTime', async () => {
        const TROVE_ID = "85477273572205332762981165440397157497675549875521584498577322101534395139618";

        const triggered = await trigger.isAdjustmentFeeZero(MARKET_ADDRESS, TROVE_ID)

        console.log("isAdjustTimePassed:", triggered);

        expect(triggered).to.be.eq(false);
    });
});
