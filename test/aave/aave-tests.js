const { expect } = require('chai');
const hre = require('hardhat');

const { getAssetInfo } = require('@defisaver/tokens');

const {
    getAaveDataProvider,
    getAaveTokenInfo,
    getAaveReserveInfo,
    getAaveReserveData,
    VARIABLE_RATE,
    STABLE_RATE,
    aaveV2assetsDefaultMarket,
} = require('../utils-aave');

const {
    getProxy,
    balanceOf,
    fetchAmountinUSDPrice,
    AAVE_MARKET,
    WETH_ADDRESS,
    timeTravel,
    getAddrFromRegistry,
    revertToSnapshot,
    takeSnapshot,
    redeploy,
    setBalance,
    approve,
    resetForkToBlock,
    impersonateAccount,
} = require('../utils');

const {
    supplyAave,
    borrowAave,
    withdrawAave,
    paybackAave,
    claimStkAave,
    startUnstakeAave,
    finalizeUnstakeAave,
    claimAaveFromStkAave,
} = require('../actions');

const aaveSupplyTest = async (testLength) => {
    describe('Aave-Supply', function () {
        this.timeout(150000);

        let senderAcc; let proxy; let dataProvider;

        before(async () => {
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            dataProvider = await getAaveDataProvider();
        });

        for (let i = 0; i < testLength; i++) {
            const tokenSymbol = aaveV2assetsDefaultMarket[i];
            const fetchedAmountWithUSD = fetchAmountinUSDPrice(tokenSymbol, '10000');

            it(`... should supply ${fetchedAmountWithUSD} ${tokenSymbol} to Aave`, async () => {
                const snapshot = await takeSnapshot();
                const assetInfo = getAssetInfo(tokenSymbol);
                if (assetInfo.symbol === 'ETH') {
                    assetInfo.address = WETH_ADDRESS;
                }

                const aaveTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const aToken = aaveTokenInfo.aTokenAddress;
                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountWithUSD,
                    assetInfo.decimals,
                );

                const balanceBefore = await balanceOf(aToken, proxy.address);
                await supplyAave(proxy, AAVE_MARKET, amount, assetInfo.address, senderAcc.address);

                const balanceAfter = await balanceOf(aToken, proxy.address);

                expect(balanceAfter).to.be.gt(balanceBefore);
                await revertToSnapshot(snapshot);
            });
        }
    });
};

const aaveBorrowTest = async (testLength) => {
    describe('Aave-Borrow', () => {
        let senderAcc; let proxy; let dataProvider;
        before(async () => {
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            dataProvider = await getAaveDataProvider();
        });

        for (let i = 0; i < testLength; ++i) {
            const tokenSymbol = aaveV2assetsDefaultMarket[i];
            const fetchedAmountWithUSD = fetchAmountinUSDPrice(tokenSymbol, '5000');
            it(`... should variable borrow ${fetchedAmountWithUSD} ${tokenSymbol} from Aave`, async () => {
                const snapshot = await takeSnapshot();
                const assetInfo = getAssetInfo(tokenSymbol);

                if (assetInfo.symbol === 'ETH') {
                    assetInfo.address = WETH_ADDRESS;
                }

                const reserveInfo = await getAaveReserveInfo(dataProvider, assetInfo.address);
                const aTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const reserveData = await getAaveReserveData(dataProvider, assetInfo.address);

                if (!reserveInfo.borrowingEnabled) {
                // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountWithUSD,
                    assetInfo.decimals,
                );

                if (reserveData.availableLiquidity.lt(amount)) {
                // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                // eth bada bing bada bum
                await supplyAave(proxy, AAVE_MARKET, hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '20000'), 18), WETH_ADDRESS, senderAcc.address);

                const balanceBefore = await balanceOf(assetInfo.address, senderAcc.address);
                const debtBalanceBefore = await balanceOf(
                    aTokenInfo.variableDebtTokenAddress,
                    proxy.address,
                );

                await borrowAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    VARIABLE_RATE,
                    senderAcc.address,
                );

                const balanceAfter = await balanceOf(assetInfo.address, senderAcc.address);
                const debtBalanceAfter = await balanceOf(
                    aTokenInfo.variableDebtTokenAddress,
                    proxy.address,
                );

                expect(debtBalanceAfter).to.be.gt(debtBalanceBefore);
                expect(balanceAfter).to.be.gt(balanceBefore);
                await revertToSnapshot(snapshot);
            });

            const fetchedAmountDiv10 = fetchAmountinUSDPrice(tokenSymbol, '500');
            it(`... should stable borrow ${fetchedAmountDiv10} ${tokenSymbol} from Aave`, async () => {
                const snapshot = await takeSnapshot();
                const assetInfo = getAssetInfo(tokenSymbol);

                if (assetInfo.symbol === 'ETH') {
                // can't currently stable borrow if position already has eth
                // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                // assetInfo.address = WETH_ADDRESS;
                }

                const reserveInfo = await getAaveReserveInfo(dataProvider, assetInfo.address);
                const aTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const reserveData = await getAaveReserveData(dataProvider, assetInfo.address);

                if (!reserveInfo.stableBorrowRateEnabled) {
                // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountDiv10,
                    assetInfo.decimals,
                );

                if (reserveData.availableLiquidity.lt(amount)) {
                // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                // eth bada bing bada bum
                await supplyAave(proxy, AAVE_MARKET, hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '20000'), 18), WETH_ADDRESS, senderAcc.address);

                const balanceBefore = await balanceOf(assetInfo.address, senderAcc.address);
                const debtBalanceBefore = await balanceOf(
                    aTokenInfo.stableDebtTokenAddress,
                    proxy.address,
                );
                await borrowAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    STABLE_RATE,
                    senderAcc.address,
                );

                const balanceAfter = await balanceOf(assetInfo.address, senderAcc.address);
                const debtBalanceAfter = await balanceOf(
                    aTokenInfo.stableDebtTokenAddress,
                    proxy.address,
                );

                expect(debtBalanceAfter).to.be.gt(debtBalanceBefore);
                expect(balanceAfter).to.be.gt(balanceBefore);
                await revertToSnapshot(snapshot);
            });
        }
    });
};

const aaveWithdrawTest = async (testLength) => {
    describe('Aave-Withdraw', function () {
        this.timeout(150000);

        let senderAcc; let proxy; let dataProvider;

        before(async () => {
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            dataProvider = await getAaveDataProvider();
        });

        for (let i = 0; i < testLength; ++i) {
            const tokenSymbol = aaveV2assetsDefaultMarket[i];
            const fetchedAmountWithUSD = fetchAmountinUSDPrice(tokenSymbol, '10000');

            it(`... should withdraw ${fetchedAmountWithUSD} ${tokenSymbol} from Aave`, async () => {
                const snapshot = await takeSnapshot();
                const assetInfo = getAssetInfo(tokenSymbol);

                if (assetInfo.symbol === 'ETH') {
                    assetInfo.address = WETH_ADDRESS;
                }

                const aaveTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const aToken = aaveTokenInfo.aTokenAddress;

                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountWithUSD,
                    assetInfo.decimals,
                );

                const aBalanceBefore = await balanceOf(aToken, proxy.address);

                if (aBalanceBefore.lte(amount)) {
                    // eslint-disable-next-line max-len
                    await supplyAave(proxy, AAVE_MARKET, amount, assetInfo.address, senderAcc.address);
                }

                const balanceBefore = await balanceOf(assetInfo.address, senderAcc.address);

                // eslint-disable-next-line max-len
                await withdrawAave(proxy, AAVE_MARKET, assetInfo.address, amount, senderAcc.address);

                const balanceAfter = await balanceOf(assetInfo.address, senderAcc.address);

                expect(balanceAfter).to.be.gt(balanceBefore);
                await revertToSnapshot(snapshot);
            });
        }
    });
};

const aavePaybackTest = async (testLength) => {
    describe('Aave-Payback', function () {
        this.timeout(80000);

        let senderAcc; let proxy; let dataProvider;

        before(async () => {
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            dataProvider = await getAaveDataProvider();
        });

        for (let i = 0; i < testLength; ++i) {
            const tokenSymbol = aaveV2assetsDefaultMarket[i];
            const fetchedAmountWithUSD = fetchAmountinUSDPrice(tokenSymbol, '5000');
            it(`... should payback variable borrow ${fetchedAmountWithUSD} ${tokenSymbol} from Aave`, async () => {
                const snapshot = await takeSnapshot();
                const assetInfo = getAssetInfo(tokenSymbol);

                if (assetInfo.symbol === 'ETH') {
                    assetInfo.address = WETH_ADDRESS;
                }

                const reserveInfo = await getAaveReserveInfo(dataProvider, assetInfo.address);
                const aTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const reserveData = await getAaveReserveData(dataProvider, assetInfo.address);

                if (!reserveInfo.borrowingEnabled) {
                    // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountWithUSD,
                    assetInfo.decimals,
                );

                if (reserveData.availableLiquidity.lt(amount)) {
                    // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                await supplyAave(
                    proxy,
                    AAVE_MARKET,
                    hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '20000'), 18),
                    WETH_ADDRESS,
                    senderAcc.address,
                );

                await borrowAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    VARIABLE_RATE,
                    senderAcc.address,
                );

                const debtBalanceBefore = await balanceOf(
                    aTokenInfo.variableDebtTokenAddress,
                    proxy.address,
                );

                await paybackAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    VARIABLE_RATE,
                    senderAcc.address,
                );

                const debtBalanceAfter = await balanceOf(
                    aTokenInfo.variableDebtTokenAddress,
                    proxy.address,
                );

                expect(debtBalanceAfter).to.be.lt(debtBalanceBefore);
                await revertToSnapshot(snapshot);
            });

            it(`... should payback stable borrow ${fetchedAmountWithUSD} ${tokenSymbol} from Aave`, async () => {
                const snapshot = await takeSnapshot();

                const assetInfo = getAssetInfo(tokenSymbol);

                if (assetInfo.symbol === 'ETH') {
                    // can't currently stable borrow if position already has eth
                    // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                    // assetInfo.address = WETH_ADDRESS;
                }

                const reserveInfo = await getAaveReserveInfo(dataProvider, assetInfo.address);
                const aTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
                const reserveData = await getAaveReserveData(dataProvider, assetInfo.address);

                if (!reserveInfo.stableBorrowRateEnabled) {
                    // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                const amount = hre.ethers.utils.parseUnits(
                    fetchedAmountWithUSD,
                    assetInfo.decimals,
                );

                if (reserveData.availableLiquidity.lt(amount)) {
                    // eslint-disable-next-line no-unused-expressions
                    expect(true).to.be.true;
                    return;
                }

                await supplyAave(
                    proxy,
                    AAVE_MARKET,
                    hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '20000'), 18),
                    WETH_ADDRESS,
                    senderAcc.address,
                );

                await borrowAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    STABLE_RATE,
                    senderAcc.address,
                );

                const debtBalanceBefore = await balanceOf(
                    aTokenInfo.stableDebtTokenAddress,
                    proxy.address,
                );

                await paybackAave(
                    proxy,
                    AAVE_MARKET,
                    assetInfo.address,
                    amount,
                    STABLE_RATE,
                    senderAcc.address,
                );

                const debtBalanceAfter = await balanceOf(
                    aTokenInfo.stableDebtTokenAddress,
                    proxy.address,
                );

                expect(debtBalanceAfter).to.be.lt(debtBalanceBefore);
                await revertToSnapshot(snapshot);
            });
        }
    });
};

const aaveClaimStkAaveTest = async () => {
    describe('Aave-claim staked aave test', function () {
        this.timeout(150000);

        const stkAaveAddr = '0x4da27a545c0c5B758a6BA100e3a049001de870f5';

        const tokenSymbol = 'WETH';
        const assetInfo = getAssetInfo(tokenSymbol);
        const supplyAmount = fetchAmountinUSDPrice(tokenSymbol, '10000');

        let senderAcc; let proxy; let proxyAddr; let dataProvider;
        let aTokenInfo; let AaveView;
        let accruedRewards;
        let snapshot;

        before(async () => {
            const aaveViewAddr = await getAddrFromRegistry('AaveView');
            AaveView = await hre.ethers.getContractAt('AaveView', aaveViewAddr);
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            proxyAddr = proxy.address;
            dataProvider = await getAaveDataProvider();
            aTokenInfo = await getAaveTokenInfo(dataProvider, assetInfo.address);
            snapshot = await takeSnapshot();
        });

        it(`... should supply ${supplyAmount} ${tokenSymbol} to Aave`, async () => {
            const aTokenBalanceBefore = await balanceOf(aTokenInfo.aTokenAddress, proxyAddr);
            // eslint-disable-next-line max-len
            await supplyAave(proxy, AAVE_MARKET, hre.ethers.utils.parseUnits(supplyAmount, 18), WETH_ADDRESS, senderAcc.address);
            const aTokenBalanceAfter = await balanceOf(aTokenInfo.aTokenAddress, proxyAddr);

            // eslint-disable-next-line max-len
            expect(aTokenBalanceAfter.sub(aTokenBalanceBefore)).to.eq(hre.ethers.utils.parseUnits(supplyAmount, 18));
        });

        it('... should accrue rewards over time', async () => {
            const secondsInMonth = 2592000;
            await timeTravel(secondsInMonth);

            // eslint-disable-next-line max-len
            await supplyAave(proxy, AAVE_MARKET, hre.ethers.constants.One, WETH_ADDRESS, senderAcc.address);
            // this is done so the getter function below returns accurate balance

            accruedRewards = await AaveView['getUserUnclaimedRewards(address)'](proxyAddr);
            expect(accruedRewards).to.be.gt(hre.ethers.constants.Zero);
        });

        it('... should not revert when claiming 0 rewards', async () => {
        // eslint-disable-next-line max-len
            await expect(claimStkAave(proxy, [aTokenInfo.aTokenAddress], hre.ethers.constants.Zero, proxyAddr)).to.not.be.reverted;
        });

        it('... should claim half of all accrued rewards', async () => {
        // eslint-disable-next-line max-len
            const stkAaveBalanceBefore = await balanceOf(stkAaveAddr, proxyAddr);
            await claimStkAave(proxy, [aTokenInfo.aTokenAddress], accruedRewards.div('2'), proxyAddr);
            const stkAaveBalanceAfter = await balanceOf(stkAaveAddr, proxyAddr);
            expect(stkAaveBalanceAfter.sub(stkAaveBalanceBefore)).to.be.eq(accruedRewards.div('2'));
        });

        it('... should claim all accrued rewards when amount > unclaimed rewards', async () => {
        // eslint-disable-next-line max-len
            await claimStkAave(proxy, [aTokenInfo.aTokenAddress], accruedRewards.add('1'), proxyAddr);
            const stkAaveBalanceAfter = await balanceOf(stkAaveAddr, proxyAddr);
            expect(stkAaveBalanceAfter / 1e18).to.be.closeTo(accruedRewards / 1e18, 0.00001);
            await revertToSnapshot(snapshot);
        });
    });
};

const aaveClaimAAVETest = async () => {
    describe('Aave-claim staked aave test', function () {
        this.timeout(150000);

        let senderAcc; let proxy;
        const AAVE_ADDR = '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9';
        const OWNER_ACC = '0xa6584b95EA4E9018b1F377dad99448EC478a150f';

        before(async () => {
            await resetForkToBlock(17970305);
            // at this block user can claim 1.357486729318663975 AAVE on his proxy
            await redeploy('AaveClaimAAVE');
            senderAcc = await hre.ethers.provider.getSigner(OWNER_ACC);

            proxy = await getProxy(OWNER_ACC);
            proxy = proxy.connect(senderAcc);
            await impersonateAccount(OWNER_ACC);
        });

        it('... should claim 1 AAVE (out of 1.35) for DSProxy from Staking Aave', async () => {
            const amountToClaim = hre.ethers.utils.parseUnits('1', 18);
            const aaveBalanceBefore = await balanceOf(AAVE_ADDR, OWNER_ACC);
            await claimAaveFromStkAave(proxy, amountToClaim, OWNER_ACC);
            const aaveBalanceAfter = await balanceOf(AAVE_ADDR, OWNER_ACC);
            console.log(aaveBalanceBefore.toString());
            console.log(aaveBalanceAfter.toString());
            expect(aaveBalanceAfter.sub(aaveBalanceBefore)).to.be.eq(amountToClaim);
        });

        it('... should claim all accrued rewards when amount > unclaimed rewards', async () => {
            const amountToClaim = hre.ethers.constants.MaxUint256;
            const aaveBalanceBefore = await balanceOf(AAVE_ADDR, OWNER_ACC);
            await claimAaveFromStkAave(proxy, amountToClaim, OWNER_ACC);
            const aaveBalanceAfter = await balanceOf(AAVE_ADDR, OWNER_ACC);
            console.log(aaveBalanceBefore.toString());
            console.log(aaveBalanceAfter.toString());
            expect(aaveBalanceAfter.sub(aaveBalanceBefore)).to.be.gt('0');
        });
    });
};

const aaveUnstakeTest = async () => {
    describe('Aave-stake on behalf of proxy and unstake test', function () {
        this.timeout(150000);

        const stkAaveAddr = '0x4da27a545c0c5B758a6BA100e3a049001de870f5';

        let senderAcc; let proxy; let aaveToken; let stkAaveContract; let snapshot;
        before(async () => {
            stkAaveContract = await hre.ethers.getContractAt('IStkAave', stkAaveAddr);
            aaveToken = await stkAaveContract.REWARD_TOKEN();
            senderAcc = (await hre.ethers.getSigners())[0];
            proxy = await getProxy(senderAcc.address);
            snapshot = await takeSnapshot();
        });
        it('... should accrue rewards over time', async () => {
        });

        it('... should stake 100 AAVE on behalf of DSProxy', async () => {
            const amount = hre.ethers.utils.parseUnits('100', 18);
            await setBalance(aaveToken, senderAcc.address, amount);
            await approve(aaveToken, stkAaveAddr, senderAcc);
            await stkAaveContract.stake(proxy.address, amount);
        });
        it('... should accrue rewards over time', async () => {
            const secondsInMonth = 2592000;
            await timeTravel(secondsInMonth);
        });

        it('... should start the process of unstaking', async () => {
            await startUnstakeAave(proxy);
            const aaveUnstakeCooldown = 1728001;
            await timeTravel(aaveUnstakeCooldown);
        });

        it('... should unstake 50 stkAave', async () => {
            const startingBalance = await balanceOf(aaveToken, senderAcc.address);
            let amount = hre.ethers.utils.parseUnits('50', 18);
            await finalizeUnstakeAave(proxy, senderAcc.address, amount);
            const midBalance = await balanceOf(aaveToken, senderAcc.address);
            amount = hre.ethers.constants.MaxUint256;
            await finalizeUnstakeAave(proxy, senderAcc.address, amount);
            const endingBalance = await balanceOf(aaveToken, senderAcc.address);
            expect(midBalance).to.be.gt(startingBalance);
            expect(endingBalance).to.be.gt(midBalance);
            await revertToSnapshot(snapshot);
        });
    });
};

const aaveDeployContracts = async () => {
    await redeploy('AaveWithdraw');
    await redeploy('AaveBorrow');
    await redeploy('AaveSupply');
    await redeploy('AavePayback');
    await redeploy('AaveClaimStkAave');
    await redeploy('AaveView');
};

const aaveFullTest = async (testLength) => {
    await aaveDeployContracts();

    await aaveSupplyTest(testLength);

    await aaveBorrowTest(testLength);

    await aaveWithdrawTest(testLength);

    await aavePaybackTest(testLength);

    await aaveClaimStkAaveTest();
};

module.exports = {
    aaveBorrowTest,
    aaveSupplyTest,
    aaveWithdrawTest,
    aavePaybackTest,
    aaveClaimStkAaveTest,
    aaveUnstakeTest,
    aaveFullTest,
    aaveDeployContracts,
    aaveClaimAAVETest,
};
