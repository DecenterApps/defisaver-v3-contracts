const hre = require('hardhat');
const { redeploy } = require('../utils');
const {ethers} = require("hardhat");

describe('LiquityV2DebtInFrontTrigger', () => {
    let trigger;
    // wstETH market
    const MARKET_ADDRESS = '0x2D4ef56cb626E9a4C90c156018BA9CE269573c61';


    before(async () => {
        trigger = await redeploy('LiquityV2DebtInFrontTrigger');
    });

    it('todo comment, only testing for now', async () => {
        const TROVE_ID = "85477273572205332762981165440397157497675549875521584498577322101534395139618";

        const debt = await trigger.getDebtInFront(MARKET_ADDRESS, TROVE_ID)

        console.log("debt in front:", debt);

    });
});

