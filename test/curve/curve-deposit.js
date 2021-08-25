const { expect } = require('chai');
const hre = require('hardhat');

const {
    balanceOf,
    getProxy,
    redeploy,
    approve,
    ETH_ADDR,
    WETH_ADDRESS,
} = require('../utils');

const {
    buyTokenIfNeeded,
    curveDeposit,
} = require('../actions.js');

const poolData = require('./poolData');

describe('Curve-Deposit', function () {
    this.timeout(1000000);
    const amount = '1000';

    let senderAcc; let senderAddr;
    let proxy; let proxyAddr;

    before(async () => {
        senderAcc = (await hre.ethers.getSigners())[0];
        senderAddr = senderAcc.address;
        proxy = await getProxy(senderAcc.address);
        proxyAddr = proxy.address;

        await redeploy('CurveDeposit');
    });

    Object.keys(poolData).map(async (poolName) => {
        it(`... should deposit [coins] via [swapContract] ${poolName}`, async () => {
            const coins = poolData[poolName].coins;
            const amounts = coins.map(() => amount);

            await Promise.all(coins.map(async (c, i) => {
                let coinToApprove = c;
                if (c === ETH_ADDR) coinToApprove = WETH_ADDRESS;
                await buyTokenIfNeeded(coinToApprove, senderAcc, proxy, amounts[i]);
                await approve(coinToApprove, proxyAddr);
            }));

            const tokensBefore = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
            await curveDeposit(proxy, senderAddr, senderAddr, poolData[poolName].swapAddr, poolData[poolName].lpTokenAddr, '0', amounts, coins, false);
            const tokensAfter = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
            expect(tokensAfter.sub(tokensBefore)).to.be.gt('0');
        });
        if (poolData[poolName].useUnderlying) {
            it(`... should deposit [underlyingCoins] via [swapContract] ${poolName}`, async () => {
                const underlyingCoins = poolData[poolName].underlyingCoins;
                const amounts = underlyingCoins.map(() => amount);

                await Promise.all(underlyingCoins.map(async (c, i) => {
                    let coinToApprove = c;
                    if (c === ETH_ADDR) coinToApprove = WETH_ADDRESS;
                    await buyTokenIfNeeded(coinToApprove, senderAcc, proxy, amounts[i]);
                    await approve(coinToApprove, proxyAddr);
                }));

                const tokensBefore = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
                await curveDeposit(proxy, senderAddr, senderAddr, poolData[poolName].swapAddr, poolData[poolName].lpTokenAddr, '0', amounts, underlyingCoins, true);
                const tokensAfter = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
                expect(tokensAfter.sub(tokensBefore)).to.be.gt('0');
            });
        }
        if (poolData[poolName].depositAddr == null) return;
        it(`... should deposit [underlyingCoins] via [depositContract] ${poolName}`, async () => {
            const underlyingCoins = poolData[poolName].underlyingCoins;
            const amounts = underlyingCoins.map(() => amount);

            await Promise.all(underlyingCoins.map(async (c, i) => {
                let coinToApprove = c;
                if (c === ETH_ADDR) coinToApprove = WETH_ADDRESS;
                await buyTokenIfNeeded(coinToApprove, senderAcc, proxy, amounts[i]);
                await approve(coinToApprove, proxyAddr);
            }));

            const tokensBefore = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
            await curveDeposit(proxy, senderAddr, senderAddr, poolData[poolName].depositAddr, poolData[poolName].lpTokenAddr, '0', amounts, underlyingCoins, false);
            const tokensAfter = await balanceOf(poolData[poolName].lpTokenAddr, senderAddr);
            expect(tokensAfter.sub(tokensBefore)).to.be.gt('0');
        });
    });
});
