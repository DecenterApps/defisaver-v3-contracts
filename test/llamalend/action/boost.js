const hre = require('hardhat');
const { expect } = require('chai');
const { getAssetInfoByAddress } = require('@defisaver/tokens');
const {
    takeSnapshot, revertToSnapshot, getProxy, redeploy,
    setBalance, approve, fetchAmountinUSDPrice,
    formatMockExchangeObj,
    setNewExchangeWrapper,
} = require('../../utils');
const {
    getControllers, collateralSupplyAmountInUsd, borrowAmountInUsd, supplyToMarket,
} = require('../utils');
const { llamalendCreate, llamalendBoost } = require('../../actions');

describe('LlamaLend-Boost', function () {
    this.timeout(80000);

    const controllers = getControllers();

    let senderAcc; let proxy; let snapshot; let view; let mockWrapper;

    before(async () => {
        senderAcc = (await hre.ethers.getSigners())[0];
        proxy = await getProxy(senderAcc.address);
        await redeploy('LlamaLendCreate');
        await redeploy('LlamaLendBoost');
        await redeploy('LlamaLendSwapper');
        mockWrapper = await redeploy('MockExchangeWrapper');
        await setNewExchangeWrapper(senderAcc, mockWrapper.address);
        view = await (await hre.ethers.getContractFactory('LlamaLendView')).deploy();
    });
    beforeEach(async () => {
        snapshot = await takeSnapshot();
    });
    afterEach(async () => {
        await revertToSnapshot(snapshot);
    });
    for (let i = 0; i < controllers.length; i++) {
        const controllerAddr = controllers[i];
        it(`should create a Llamalend position and then boost it in ${controllerAddr} Llamalend market`, async () => {
            await supplyToMarket(controllerAddr);
            const controller = await hre.ethers.getContractAt('ILlamaLendController', controllerAddr);
            const collTokenAddr = await controller.collateral_token();
            const debtTokenAddr = await controller.borrowed_token();
            const collToken = getAssetInfoByAddress(collTokenAddr);
            const debtToken = getAssetInfoByAddress(debtTokenAddr);
            const supplyAmount = fetchAmountinUSDPrice(
                collToken.symbol, collateralSupplyAmountInUsd,
            );
            const borrowAmount = fetchAmountinUSDPrice(
                debtToken.symbol, borrowAmountInUsd,
            );
            const supplyAmountInWei = (hre.ethers.utils.parseUnits(
                supplyAmount, collToken.decimals,
            )).mul(2);
            const borrowAmountWei = hre.ethers.utils.parseUnits(
                borrowAmount, debtToken.decimals,
            );

            await setBalance(collTokenAddr, senderAcc.address, supplyAmountInWei);
            await approve(collTokenAddr, proxy.address, senderAcc);
            await llamalendCreate(
                proxy, controllerAddr, senderAcc.address, senderAcc.address,
                supplyAmountInWei, borrowAmountWei, 10,
            );

            const exchangeData = await formatMockExchangeObj(
                debtToken,
                collToken,
                borrowAmountWei.mul(2),
            );
            const infoBeforeBoost = await view.callStatic.userData(controllerAddr, proxy.address);
            console.log(infoBeforeBoost.collRatio / 1e18);
            await llamalendBoost(
                proxy,
                controllerAddr,
                exchangeData,
            );
            const infoAfterBoost = await view.callStatic.userData(controllerAddr, proxy.address);
            console.log(infoAfterBoost.collRatio / 1e18);
            expect(infoAfterBoost.collRatio).to.be.lt(infoBeforeBoost.collRatio);
            expect(infoAfterBoost.debtAmount).to.be.gt(infoBeforeBoost.debtAmount);
            // eslint-disable-next-line max-len
            expect(infoAfterBoost.marketCollateralAmount).to.be.gt(infoBeforeBoost.marketCollateralAmount);
        });
    }
});
