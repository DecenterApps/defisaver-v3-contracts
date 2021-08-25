const { expect } = require('chai');
const hre = require('hardhat');

const {
    balanceOf,
    getProxy,
    redeploy,
    WETH_ADDRESS,
    approve,
    ETH_ADDR,
} = require('../utils');

const {
    curveSwap,
    buyTokenIfNeeded,
} = require('../actions.js');

const poolData = require('./poolData');

describe('Curve-Swap', function () {
    this.timeout(1000000);
    const amount = '1000';

    let senderAcc; let senderAddr;
    let proxy; let proxyAddr;

    before(async () => {
        senderAcc = (await hre.ethers.getSigners())[0];
        senderAddr = senderAcc.address;
        proxy = await getProxy(senderAcc.address);
        proxyAddr = proxy.address;

        await redeploy('CurveSwap');
    });

    Object.keys(poolData).map(async (poolName) => {
        it(`... should swap coins ${poolName}`, async () => {
            const coins = poolData[poolName].coins;

            let coinToApprove = coins[0];
            if (coinToApprove === ETH_ADDR) coinToApprove = WETH_ADDRESS;
            await buyTokenIfNeeded(coinToApprove, senderAcc, proxy, amount);
            await approve(coinToApprove, proxyAddr);

            const tokensBefore = await balanceOf(coins[1], senderAddr);
            await curveSwap(proxy, senderAddr, senderAddr, poolData[poolName].swapAddr, coins[0], coins[1], amount, '0');

            const tokensAfter = await balanceOf(coins[1], senderAddr);
            expect(tokensAfter.sub(tokensBefore)).to.be.gt('0');
        });

        it(`... should swap underlying coins ${poolName}`, async () => {
            const underlyingCoins = poolData[poolName].underlyingCoins;

            let coinToApprove = underlyingCoins[0];
            if (coinToApprove === ETH_ADDR) coinToApprove = WETH_ADDRESS;
            await buyTokenIfNeeded(coinToApprove, senderAcc, proxy, amount);
            await approve(coinToApprove, proxyAddr);

            const tokensBefore = await balanceOf(underlyingCoins[1], senderAddr);
            await curveSwap(proxy, senderAddr, senderAddr, poolData[poolName].swapAddr, underlyingCoins[0], underlyingCoins[1], amount, '0');

            const tokensAfter = await balanceOf(underlyingCoins[1], senderAddr);
            expect(tokensAfter.sub(tokensBefore)).to.be.gt('0');
        });
    });
});
