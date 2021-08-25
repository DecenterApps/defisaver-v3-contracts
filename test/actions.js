const dfs = require('@defisaver/sdk');
const hre = require('hardhat');

const { getAssetInfo } = require('@defisaver/tokens');

const {
    approve,
    getAddrFromRegistry,
    nullAddress,
    WETH_ADDRESS,
    UNISWAP_WRAPPER,
    balanceOf,
    formatExchangeObj,
    isEth,
    depositToWeth,
    MAX_UINT128,
    fetchAmountinUSDPrice,
} = require('./utils');

const { getVaultsForUser, MCD_MANAGER_ADDR } = require('./utils-mcd');

const { getSecondTokenAmount } = require('./utils-uni');

const { getHints, LiquityActionIds } = require('./utils-liquity');

const sell = async (proxy, sellAddr, buyAddr, sellAmount, wrapper, from, to, fee = 0) => {
    const dfsSellAddr = await getAddrFromRegistry('DFSSell');

    const exchangeObject = formatExchangeObj(
        sellAddr,
        buyAddr,
        sellAmount.toString(),
        wrapper,
        0,
        fee,
    );

    const sellAction = new dfs.actions.basic.SellAction(exchangeObject, from, to);

    const functionData = sellAction.encodeForDsProxyCall()[1];

    if (isEth(sellAddr)) {
        await depositToWeth(sellAmount.toString());
    }
    await approve(sellAddr, proxy.address);

    await proxy['execute(address,bytes)'](dfsSellAddr, functionData, { gasLimit: 3000000 });
};

const buy = async (proxy, sellAddr, buyAddr,
    sellAmount, buyAmount, wrapper, from, to, uniV3fee = 0) => {
    const dfsBuyAddr = await getAddrFromRegistry('DFSBuy');

    const exchangeObject = formatExchangeObj(
        sellAddr,
        buyAddr,
        sellAmount.toString(),
        wrapper,
        buyAmount,
        uniV3fee,
    );

    const sellAction = new dfs.actions.basic.SellAction(exchangeObject, from, to);

    const functionData = sellAction.encodeForDsProxyCall()[1];

    if (isEth(sellAddr)) {
        await depositToWeth(sellAmount.toString());
    }

    await approve(sellAddr, proxy.address);

    await proxy['execute(address,bytes)'](dfsBuyAddr, functionData, { gasLimit: 3000000 });
};

const openMcd = async (proxy, makerAddresses, joinAddr) => {
    const mcdOpenAddr = await getAddrFromRegistry('McdOpen');

    const openMyVault = new dfs.actions.maker.MakerOpenVaultAction(joinAddr, MCD_MANAGER_ADDR);
    const functionData = openMyVault.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdOpenAddr, functionData, { gasLimit: 3000000 });

    const vaultsAfter = await getVaultsForUser(proxy.address, makerAddresses);

    return vaultsAfter.ids[vaultsAfter.ids.length - 1].toString();
};

const supplyMcd = async (proxy, vaultId, amount, tokenAddr, joinAddr, from) => {
    const tokenBalance = await balanceOf(tokenAddr, from);

    if (tokenBalance.lt(amount)) {
        if (isEth(tokenAddr)) {
            await depositToWeth(amount.toString());
        } else {
            await sell(
                proxy,
                WETH_ADDRESS,
                tokenAddr,
                hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '100000'), 18),
                UNISWAP_WRAPPER,
                from,
                from,
            );
        }
    }
    const mcdSupplyAddr = await getAddrFromRegistry('McdSupply');

    await approve(tokenAddr, proxy.address);

    const mcdSupplyAction = new dfs.actions.maker.MakerSupplyAction(
        vaultId,
        amount,
        joinAddr,
        from,
        MCD_MANAGER_ADDR,
    );
    const functionData = mcdSupplyAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdSupplyAddr, functionData, { gasLimit: 3000000 });
};

const paybackMcd = async (proxy, vaultId, amount, from, daiAddr) => {
    const mcdPaybackAddr = await getAddrFromRegistry('McdPayback');

    await approve(daiAddr, proxy.address);

    const mcdPaybackAction = new dfs.actions.maker.MakerPaybackAction(
        vaultId,
        amount,
        from,
        MCD_MANAGER_ADDR,
    );
    const functionData = mcdPaybackAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdPaybackAddr, functionData, { gasLimit: 3000000 });
};

const withdrawMcd = async (proxy, vaultId, amount, joinAddr, to) => {
    const mcdWithdrawAddr = await getAddrFromRegistry('McdWithdraw');

    const mcdWithdrawAction = new dfs.actions.maker.MakerWithdrawAction(
        vaultId,
        amount,
        joinAddr,
        to,
        MCD_MANAGER_ADDR,
    );
    const functionData = mcdWithdrawAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const supplyAave = async (proxy, market, amount, tokenAddr, from) => {
    const tokenBalance = await balanceOf(tokenAddr, from);

    if (tokenBalance.lt(amount)) {
        if (isEth(tokenAddr)) {
            await depositToWeth(amount.toString());
        } else {
            await sell(
                proxy,
                WETH_ADDRESS,
                tokenAddr,
                hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '15000'), 18),
                UNISWAP_WRAPPER,
                from,
                from,
            );
        }
    }
    const aaveSupplyAddr = await getAddrFromRegistry('AaveSupply');

    await approve(tokenAddr, proxy.address);

    const aaveSupplyAction = new dfs.actions.aave.AaveSupplyAction(
        market,
        tokenAddr,
        amount,
        from,
        nullAddress,
    );
    const functionData = aaveSupplyAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](aaveSupplyAddr, functionData, { gasLimit: 3000000 });
};

const withdrawAave = async (proxy, market, tokenAddr, amount, to) => {
    const aaveWithdrawAddr = await getAddrFromRegistry('AaveWithdraw');

    const aaveWithdrawAction = new dfs.actions.aave.AaveWithdrawAction(
        market,
        tokenAddr,
        amount,
        to,
    );
    const functionData = aaveWithdrawAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](aaveWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const borrowAave = async (proxy, market, tokenAddr, amount, rateMode, to) => {
    const aaveBorrowAddr = await getAddrFromRegistry('AaveBorrow');

    const aaveBorrowAction = new dfs.actions.aave.AaveBorrowAction(
        market,
        tokenAddr,
        amount,
        rateMode,
        to,
        nullAddress,
    );
    const functionData = aaveBorrowAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](aaveBorrowAddr, functionData, { gasLimit: 3000000 });
};

const paybackAave = async (proxy, market, tokenAddr, amount, rateMode, from) => {
    const aavePaybackAddr = await getAddrFromRegistry('AavePayback');

    if (isEth(tokenAddr)) {
        await depositToWeth(amount.toString());
    }

    await approve(tokenAddr, proxy.address);

    const aavePaybackAction = new dfs.actions.aave.AavePaybackAction(
        market,
        tokenAddr,
        amount,
        rateMode,
        from,
        nullAddress,
    );
    const functionData = aavePaybackAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](aavePaybackAddr, functionData, { gasLimit: 4000000 });
};

const claimStkAave = async (proxy, assets, amount, to) => {
    const aaveClaimStkAaveAddr = await getAddrFromRegistry('AaveClaimStkAave');

    const aaveClaimStkAaveAction = new dfs.actions.aave.AaveClaimStkAaveAction(
        assets,
        amount,
        to,
    );
    const functionData = aaveClaimStkAaveAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](aaveClaimStkAaveAddr, functionData, { gasLimit: 4000000 });
};

const supplyComp = async (proxy, cTokenAddr, tokenAddr, amount, from) => {
    const tokenBalance = await balanceOf(tokenAddr, from);

    if (tokenBalance.lt(amount)) {
        if (isEth(tokenAddr)) {
            await depositToWeth(amount.toString());
        } else {
            await sell(
                proxy,
                WETH_ADDRESS,
                tokenAddr,
                hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '15000'), 18),
                UNISWAP_WRAPPER,
                from,
                from,
            );
        }
    }

    const compSupplyAddr = await getAddrFromRegistry('CompSupply');

    await approve(tokenAddr, proxy.address);

    const compSupplyAction = new dfs.actions.compound.CompoundSupplyAction(
        cTokenAddr,
        amount,
        from,
        true,
    );

    const functionData = compSupplyAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](compSupplyAddr, functionData, { gasLimit: 3000000 });
};

const withdrawComp = async (proxy, cTokenAddr, amount, to) => {
    const compWithdrawAddr = await getAddrFromRegistry('CompWithdraw');

    const compWithdrawAction = new dfs.actions.compound.CompoundWithdrawAction(
        cTokenAddr,
        amount,
        to,
    );
    const functionData = compWithdrawAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](compWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const borrowComp = async (proxy, cTokenAddr, amount, to) => {
    const compBorrowAddr = await getAddrFromRegistry('CompBorrow');

    const compBorrowAction = new dfs.actions.compound.CompoundBorrowAction(cTokenAddr, amount, to);
    const functionData = compBorrowAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](compBorrowAddr, functionData, { gasLimit: 3000000 });
};

const paybackComp = async (proxy, cTokenAddr, amount, from) => {
    const compPaybackAddr = await getAddrFromRegistry('CompPayback');

    if (cTokenAddr.toLowerCase() === getAssetInfo('cETH').address.toLowerCase()) {
        const wethBalance = await balanceOf(WETH_ADDRESS, from);
        if (wethBalance.lt(amount)) {
            await depositToWeth(amount.toString());
        }
    }

    await approve(cTokenAddr, proxy.address);

    const compPaybackAction = new dfs.actions.compound.CompoundPaybackAction(
        cTokenAddr,
        amount,
        from,
    );
    const functionData = compPaybackAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](compPaybackAddr, functionData, { gasLimit: 4000000 });
};

const generateMcd = async (proxy, vaultId, amount, to) => {
    const mcdGenerateAddr = await getAddrFromRegistry('McdGenerate');

    const mcdGenerateAction = new dfs.actions.maker.MakerGenerateAction(
        vaultId,
        amount,
        to,
        MCD_MANAGER_ADDR,
    );
    const functionData = mcdGenerateAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdGenerateAddr, functionData, { gasLimit: 3000000 });
};

const openVault = async (makerAddresses, proxy, joinAddr, tokenData, collAmount, daiAmount) => {
    const vaultId = await openMcd(proxy, makerAddresses, joinAddr);
    const from = proxy.signer.address;
    const to = proxy.signer.address;

    const amountDai = hre.ethers.utils.parseUnits(daiAmount, 18);
    const amountColl = hre.ethers.utils.parseUnits(collAmount, tokenData.decimals);

    await supplyMcd(proxy, vaultId, amountColl, tokenData.address, joinAddr, from);
    await generateMcd(proxy, vaultId, amountDai, to);
    return vaultId;
};

const uniSupply = async (proxy, addrTokenA, tokenADecimals, addrTokenB, amount, from, to) => {
    const uniSupplyAddr = await getAddrFromRegistry('UniSupply');

    const amountA = hre.ethers.utils.parseUnits(amount, tokenADecimals);
    const amountB = await getSecondTokenAmount(addrTokenA, addrTokenB, amountA);

    const amountAMin = amountA.div('2');
    const amountBMin = amountB.div('2');

    // buy tokens
    const tokenBalanceA = await balanceOf(addrTokenA, from);
    const tokenBalanceB = await balanceOf(addrTokenB, from);

    if (isEth(addrTokenA)) {
        await depositToWeth(amountA);
    }

    if (isEth(addrTokenB)) {
        await depositToWeth(amountB);
    }

    if (tokenBalanceA.lt(amountA)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            addrTokenA,
            hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '15000'), 18),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }

    if (tokenBalanceB.lt(amountB)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            addrTokenB,
            hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '15000'), 18),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }

    const deadline = Date.now() + Date.now();

    const uniObj = [
        addrTokenA,
        addrTokenB,
        from,
        to,
        amountA,
        amountB,
        amountAMin,
        amountBMin,
        deadline,
    ];

    const uniSupplyAction = new dfs.actions.uniswap.UniswapSupplyAction(...uniObj);

    await approve(addrTokenA, proxy.address);
    await approve(addrTokenB, proxy.address);

    const functionData = uniSupplyAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](uniSupplyAddr, functionData, {
        gasLimit: 3000000,
    });
};

const uniWithdraw = async (proxy, addrTokenA, addrTokenB, lpAddr, liquidity, to, from) => {
    const uniWithdrawAddr = await getAddrFromRegistry('UniWithdraw');

    const amountAMin = 0;
    const amountBMin = 0;
    const deadline = Date.now() + Date.now();

    await approve(lpAddr, proxy.address);

    const uniObj = [addrTokenA, addrTokenB, liquidity, to, from, amountAMin, amountBMin, deadline];

    const uniWithdrawAction = new dfs.actions.uniswap.UniswapWithdrawAction(...uniObj);

    const functionData = uniWithdrawAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](uniWithdrawAddr, functionData, {
        gasLimit: 3000000,
    });
};

const claimComp = async (proxy, cSupplyAddresses, cBorrowAddresses, from, to) => {
    const compClaimAddr = await getAddrFromRegistry('CompClaim');

    const claimCompAction = new dfs.Action(
        'CompClaim',
        '0x0',
        ['address[]', 'address[]', 'address', 'address'],
        [cSupplyAddresses, cBorrowAddresses, from, to],
    );

    const functionData = claimCompAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](compClaimAddr, functionData, {
        gasLimit: 3000000,
    });
};

const mcdGive = async (proxy, vaultId, newOwner, createProxy) => {
    const mcdGiveAddr = await getAddrFromRegistry('McdGive');

    const mcdGiveAction = new dfs.Action(
        'McdGive',
        '0x0',
        ['uint256', 'address', 'bool', 'address'],
        [vaultId, newOwner.address, createProxy, MCD_MANAGER_ADDR],
    );

    const functionData = mcdGiveAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdGiveAddr, functionData, {
        gasLimit: 3000000,
    });
};

const mcdMerge = async (proxy, srcVaultId, destVaultId) => {
    const mcdMergeAddr = await getAddrFromRegistry('McdMerge');

    const mcdMergeAction = new dfs.Action(
        'McdMerge',
        '0x0',
        ['uint256', 'uint256', 'address'],
        [srcVaultId, destVaultId, MCD_MANAGER_ADDR],
    );

    const functionData = mcdMergeAction.encodeForDsProxyCall()[1];

    await proxy['execute(address,bytes)'](mcdMergeAddr, functionData, {
        gasLimit: 3000000,
    });
};

const reflexerOpen = async (proxy, adapterAddr) => {
    const reflexerOpenAddr = await getAddrFromRegistry('ReflexerOpen');

    const openMySafe = new dfs.actions.reflexer.ReflexerOpenSafeAction(adapterAddr);
    const functionData = openMySafe.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](reflexerOpenAddr, functionData, { gasLimit: 3000000 });
};

const reflexerSupply = async (proxy, safeId, amount, adapterAddr, from) => {
    await approve(WETH_ADDRESS, proxy.address);

    const reflexerSupplyAddr = await getAddrFromRegistry('ReflexerSupply');

    const supplyMySafe = new dfs.actions.reflexer.ReflexerSupplyAction(
        safeId,
        amount,
        adapterAddr,
        from,
    );

    const functionData = supplyMySafe.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](reflexerSupplyAddr, functionData, { gasLimit: 3000000 });
};

const reflexerPayback = async (proxy, safeId, amount, from, raiAddr) => {
    const reflexerPaybackAddress = await getAddrFromRegistry('ReflexerPayback');

    await approve(raiAddr, proxy.address);

    const reflexerPaybackAction = new dfs.actions.reflexer.ReflexerPaybackAction(
        safeId,
        amount,
        from,
    );
    const functionData = reflexerPaybackAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](reflexerPaybackAddress, functionData, { gasLimit: 3000000 });
};

const reflexerWithdraw = async (proxy, safeId, amount, adapterAddr, to) => {
    const reflexerWithdrawAddr = await getAddrFromRegistry('ReflexerWithdraw');

    const reflexerWithdrawAction = new dfs.actions.reflexer.ReflexerWithdrawAction(
        safeId,
        amount,
        adapterAddr,
        to,
    );
    const functionData = reflexerWithdrawAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](reflexerWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const reflexerGenerate = async (proxy, safeId, amount, to) => {
    const reflexerGenerateAddr = await getAddrFromRegistry('ReflexerGenerate');

    const reflexerGenerateAction = new dfs.actions.reflexer.ReflexerGenerateAction(
        safeId,
        amount,
        to,
    );
    const functionData = reflexerGenerateAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](reflexerGenerateAddr, functionData, { gasLimit: 3000000 });
};

const liquityOpen = async (proxy, maxFeePercentage, collAmount, LUSDAmount, from, to) => {
    const liquityOpenAddr = await getAddrFromRegistry('LiquityOpen');

    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Open, from, collAmount, LUSDAmount,
    );

    const liquityOpenAction = new dfs.actions.liquity.LiquityOpenAction(
        maxFeePercentage, collAmount, LUSDAmount, from, to, upperHint, lowerHint,
    );

    const functionData = liquityOpenAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityOpenAddr, functionData, { gasLimit: 3000000 });
};

const liquityBorrow = async (proxy, maxFeePercentage, LUSDAmount, to) => {
    const liquityBorrowAddr = await getAddrFromRegistry('LiquityBorrow');

    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Borrow, hre.ethers.constants.AddressZero, 0, LUSDAmount,
    );

    const liquityBorrowAction = new dfs.actions.liquity.LiquityBorrowAction(
        maxFeePercentage, LUSDAmount, to, upperHint, lowerHint,
    );

    const functionData = liquityBorrowAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityBorrowAddr, functionData, { gasLimit: 3000000 });
};

const liquityPayback = async (proxy, LUSDAmount, from) => {
    const liquityPaybackAddr = await getAddrFromRegistry('LiquityPayback');

    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Payback, from, 0, LUSDAmount,
    );

    const liquityPaybackAction = new dfs.actions.liquity.LiquityPaybackAction(
        LUSDAmount, from, upperHint, lowerHint,
    );

    const functionData = liquityPaybackAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityPaybackAddr, functionData, { gasLimit: 3000000 });
};

const liquitySupply = async (proxy, collAmount, from) => {
    const liquitySupplyAddr = await getAddrFromRegistry('LiquitySupply');

    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Supply, from, collAmount, 0,
    );

    const liquitySupplyAction = new dfs.actions.liquity.LiquitySupplyAction(
        collAmount, from, upperHint, lowerHint,
    );

    const functionData = liquitySupplyAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquitySupplyAddr, functionData, { gasLimit: 3000000 });
};

const liquityWithdraw = async (proxy, collAmount, to) => {
    const liquityWithdrawAddr = await getAddrFromRegistry('LiquityWithdraw');

    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Withdraw, hre.ethers.constants.AddressZero, collAmount, 0,
    );

    const liquityWithdrawAction = new dfs.actions.liquity.LiquityWithdrawAction(
        collAmount, to, upperHint, lowerHint,
    );

    const functionData = liquityWithdrawAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const liquityClose = async (proxy, from, to) => {
    const liquityCloseAddr = await getAddrFromRegistry('LiquityClose');

    const LiquityCloseAction = new dfs.actions.liquity.LiquityCloseAction(
        from, to,
    );

    const functionData = LiquityCloseAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityCloseAddr, functionData, { gasLimit: 3000000 });
};

const liquityRedeem = async (proxy, lusdAmount, from, to, maxFeePercentage) => {
    const maxIterations = 0;
    const liquityRedeemAddr = await getAddrFromRegistry('LiquityRedeem');

    const liquityViewAddr = await getAddrFromRegistry('LiquityView');
    const liquityView = await hre.ethers.getContractAt('LiquityView', liquityViewAddr);
    const { collPrice } = await liquityView['getTroveInfo(address)'](proxy.address);
    const { firstRedemptionHint, partialRedemptionHintNICR, truncatedLUSDamount } = await liquityView['getRedemptionHints(uint256,uint256,uint256)'](lusdAmount, collPrice, maxIterations);
    const { hintAddress } = await liquityView['getApproxHint(uint256,uint256,uint256)'](partialRedemptionHintNICR, 200, 42);
    const { upperHint, lowerHint } = await liquityView['findInsertPosition(uint256,address,address)'](partialRedemptionHintNICR, hintAddress, hintAddress);

    const liquityRedeemAction = new dfs.actions.liquity.LiquityRedeemAction(
        truncatedLUSDamount,
        from,
        to,
        firstRedemptionHint,
        upperHint,
        lowerHint,
        partialRedemptionHintNICR,
        maxIterations,
        maxFeePercentage,
    );

    const functionData = liquityRedeemAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityRedeemAddr, functionData, { gasLimit: 3000000 });
};

const liquityStake = async (proxy, lqtyAmount, from, wethTo, lusdTo) => {
    const liquityStakeAddr = await getAddrFromRegistry('LiquityStake');

    const LiquityStakeAction = new dfs.actions.liquity.LiquityStakeAction(
        lqtyAmount, from, wethTo, lusdTo,
    );

    const functionData = LiquityStakeAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityStakeAddr, functionData, { gasLimit: 3000000 });
};

const liquityUnstake = async (proxy, lqtyAmount, to, wethTo, lusdTo) => {
    const liquityUnstakeAddr = await getAddrFromRegistry('LiquityUnstake');

    const LiquityUnstakeAction = new dfs.actions.liquity.LiquityUnstakeAction(
        lqtyAmount, to, wethTo, lusdTo,
    );

    const functionData = LiquityUnstakeAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityUnstakeAddr, functionData, { gasLimit: 3000000 });
};

const liquitySPDeposit = async (proxy, LUSDAmount, from, wethTo, lqtyTo) => {
    const liquitySPDepositAddr = await getAddrFromRegistry('LiquitySPDeposit');

    const liquitySPDepositAction = new dfs.actions.liquity.LiquitySPDepositAction(
        LUSDAmount, from, wethTo, lqtyTo,
    );

    const functionData = liquitySPDepositAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquitySPDepositAddr, functionData, { gasLimit: 3000000 });
};

const liquitySPWithdraw = async (proxy, LUSDAmount, to, wethTo, lqtyTo) => {
    const liquitySPWithdrawAddr = await getAddrFromRegistry('LiquitySPWithdraw');

    const liquitySPWithdrawAction = new dfs.actions.liquity.LiquitySPWithdrawAction(
        LUSDAmount, to, wethTo, lqtyTo,
    );

    const functionData = liquitySPWithdrawAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquitySPWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const liquityEthGainToTrove = async (proxy, lqtyTo) => {
    const liquityEthGainToTroveAddr = await getAddrFromRegistry('LiquityEthGainToTrove');

    const liquityViewAddr = await getAddrFromRegistry('LiquityView');
    const liquityView = await hre.ethers.getContractAt('LiquityView', liquityViewAddr);

    const { ethGain } = await liquityView['getDepositorInfo(address)'](proxy.address);
    const { upperHint, lowerHint } = await getHints(
        proxy.address, LiquityActionIds.Supply, '0x0000000000000000000000000000000000000000', ethGain, 0,
    );

    const liquityEthGainToTroveAction = new dfs.actions.liquity.LiquityEthGainToTroveAction(
        lqtyTo, upperHint, lowerHint,
    );

    const functionData = liquityEthGainToTroveAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](liquityEthGainToTroveAddr, functionData, { gasLimit: 3000000 });
};

const uniV3CreatePool = async (proxy, token0, token1, fee, tickLower, tickUpper, amount0Desired,
    amount1Desired, recipient, from, sqrtPriceX96) => {
    const uniCreatePoolAddress = await getAddrFromRegistry('UniCreatePoolV3');
    const amount0Min = 0;
    const amount1Min = 0;
    // buy tokens
    const wethBalance = await balanceOf(WETH_ADDRESS, from);

    const wethAmountToDeposit = hre.ethers.utils.parseUnits('20', 18);

    if (wethBalance.lt(wethAmountToDeposit)) {
        await depositToWeth(wethAmountToDeposit);
    }
    const tokenBalance0 = await balanceOf(token0, from);
    const tokenBalance1 = await balanceOf(token1, from);
    if (tokenBalance0.lt(amount0Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token0,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }

    if (tokenBalance1.lt(amount1Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token1,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }
    const deadline = Date.now() + Date.now();
    const uniCreatePoolAction = new dfs.actions.uniswapV3.UniswapV3CreatePoolAction(
        token0,
        token1,
        fee,
        tickLower,
        tickUpper,
        amount0Desired,
        amount1Desired,
        amount0Min,
        amount1Min,
        recipient,
        deadline,
        from,
        sqrtPriceX96,
    );
    await approve(token0, proxy.address);
    await approve(token1, proxy.address);

    const functionData = uniCreatePoolAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](uniCreatePoolAddress, functionData);
};

const uniV3Mint = async (proxy, token0, token1, fee, tickLower, tickUpper, amount0Desired,
    amount1Desired, recipient, from) => {
    const uniMintV3Address = await getAddrFromRegistry('UniMintV3');
    const amount0Min = 0;
    const amount1Min = 0;
    // buy tokens
    const wethBalance = await balanceOf(WETH_ADDRESS, from);

    const wethAmountToDeposit = hre.ethers.utils.parseUnits('20', 18);

    if (wethBalance.lt(wethAmountToDeposit)) {
        await depositToWeth(wethAmountToDeposit);
    }
    const tokenBalance0 = await balanceOf(token0, from);
    const tokenBalance1 = await balanceOf(token1, from);
    if (tokenBalance0.lt(amount0Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token0,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }

    if (tokenBalance1.lt(amount1Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token1,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }
    const deadline = Date.now() + Date.now();
    const uniMintV3Action = new dfs.actions.uniswapV3.UniswapV3MintAction(
        token0,
        token1,
        fee,
        tickLower,
        tickUpper,
        amount0Desired,
        amount1Desired,
        amount0Min,
        amount1Min,
        recipient,
        deadline,
        from,
    );
    await approve(token0, proxy.address);
    await approve(token1, proxy.address);

    const functionData = uniMintV3Action.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](uniMintV3Address, functionData, { gasLimit: 3000000 });
};

const uniV3Supply = async (proxy, tokenId, amount0Desired,
    amount1Desired, from, token0, token1) => {
    const uniSupplyV3Address = await getAddrFromRegistry('UniSupplyV3');

    const amount0Min = 0;
    const amount1Min = 0;

    const wethAmountToDeposit = hre.ethers.utils.parseUnits('20', 18);

    const wethBalance = await balanceOf(WETH_ADDRESS, from);
    if (wethBalance.lt(wethAmountToDeposit)) {
        await depositToWeth(wethAmountToDeposit);
    }

    const tokenBalance0 = await balanceOf(token0, from);
    const tokenBalance1 = await balanceOf(token1, from);

    // buy tokens
    if (tokenBalance0.lt(amount0Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token0,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }

    if (tokenBalance1.lt(amount1Desired)) {
        await sell(
            proxy,
            WETH_ADDRESS,
            token1,
            wethAmountToDeposit.div(2),
            UNISWAP_WRAPPER,
            from,
            from,
        );
    }
    const deadline = Date.now() + Date.now();

    const uniSupplyV3Action = new dfs.actions.uniswapV3.UniswapV3SupplyAction(
        tokenId,
        amount0Desired,
        amount1Desired,
        amount0Min,
        amount1Min,
        deadline,
        from,
        token0,
        token1,
    );
    await approve(token0, proxy.address);
    await approve(token1, proxy.address);

    const functionData = uniSupplyV3Action.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](uniSupplyV3Address, functionData, { gasLimit: 3000000 });
};

const uniV3Withdraw = async (proxy, tokenId, liquidity, recipient) => {
    const uniWithdrawV3Address = await getAddrFromRegistry('UniWithdrawV3');
    const deadline = Date.now() + Date.now();
    const uniWithdrawV3Action = new dfs.actions.uniswapV3.UniswapV3WithdrawAction(
        tokenId,
        liquidity,
        0,
        0,
        deadline,
        recipient,
        MAX_UINT128,
        MAX_UINT128,
        recipient,
    );
    const functionData = uniWithdrawV3Action.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](uniWithdrawV3Address, functionData, { gasLimit: 3000000 });
};

const uniV3Collect = async (proxy, tokenId, recipient, amount0Max, amount1Max) => {
    const uniCollectV3Address = await getAddrFromRegistry('UniCollectV3');
    const uniCollectV3Action = new dfs.actions.uniswapV3.UniswapV3CollectAction(
        tokenId,
        recipient,
        amount0Max,
        amount1Max,
        recipient,
    );
    const functionData = uniCollectV3Action.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](uniCollectV3Address, functionData, { gasLimit: 3000000 });
};

const dydxSupply = async (proxy, tokenAddr, amount, from) => {
    await approve(tokenAddr, proxy.address);

    const dydxSupplyAddr = await getAddrFromRegistry('DyDxSupply');

    const dydxSupplyAction = new dfs.actions.dydx.DyDxSupplyAction(
        tokenAddr,
        amount,
        from,
    );
    const functionData = dydxSupplyAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](dydxSupplyAddr, functionData, { gasLimit: 3000000 });
};

const dydxWithdraw = async (proxy, tokenAddr, amount, to) => {
    const dydxWithdrawAddr = await getAddrFromRegistry('DyDxWithdraw');

    const dydxWithdrawAction = new dfs.actions.dydx.DyDxWithdrawAction(
        tokenAddr,
        amount,
        to,
    );
    const functionData = dydxWithdrawAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](dydxWithdrawAddr, functionData, { gasLimit: 3000000 });
};

const buyTokenIfNeeded = async (tokenAddr, senderAcc, proxy, standardAmount) => {
    const tokenBalance = await balanceOf(tokenAddr, senderAcc.address);
    if (tokenBalance.lt(standardAmount)) {
        if (isEth(tokenAddr)) {
            await depositToWeth(standardAmount.toString());
        } else {
            await sell(
                proxy,
                WETH_ADDRESS,
                tokenAddr,
                hre.ethers.utils.parseUnits(fetchAmountinUSDPrice('WETH', '15000'), 18),
                UNISWAP_WRAPPER,
                senderAcc.address,
                senderAcc.address,
            );
        }
    }
};

const yearnSupply = async (token, amount, from, to, proxy) => {
    const yearnSupplyAddress = await getAddrFromRegistry('YearnSupply');
    const yearnSupplyAction = new dfs.actions.yearn.YearnSupplyAction(
        token,
        amount,
        from,
        to,
    );
    const functionData = yearnSupplyAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](yearnSupplyAddress, functionData, { gasLimit: 3000000 });
};

const yearnWithdraw = async (token, amount, from, to, proxy) => {
    const yearnWithdrawAddress = await getAddrFromRegistry('YearnWithdraw');
    const yearnWithdrawAction = new dfs.actions.yearn.YearnWithdrawAction(
        token,
        amount,
        from,
        to,
    );
    const functionData = yearnWithdrawAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](yearnWithdrawAddress, functionData, { gasLimit: 3000000 });
};

const lidoStake = async (amount, from, to, proxy) => {
    const lidoStakeAddress = await getAddrFromRegistry('LidoStake');
    const lidoStakeAction = new dfs.actions.lido.LidoStakeAction(
        amount,
        from,
        to,
    );
    const functionData = lidoStakeAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](lidoStakeAddress, functionData, { gasLimit: 3000000 });
};

const reflexerSaviourDeposit = async (proxy, from, safeId, lpTokenAmount) => {
    const reflexerSaviourDepositAddress = await getAddrFromRegistry('ReflexerNativeUniV2SaviourDeposit');
    // eslint-disable-next-line max-len
    const reflexerSaviourDepositAction = new dfs.actions.reflexer.ReflexerNativeUniV2SaviourDepositAction(
        from,
        safeId,
        lpTokenAmount,
    );
    const functionData = reflexerSaviourDepositAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](reflexerSaviourDepositAddress, functionData, { gasLimit: 3000000 });
};

const reflexerSaviourWithdraw = async (proxy, to, safeId, lpTokenAmount) => {
    const reflexerSaviourWithdrawAddress = await getAddrFromRegistry('ReflexerNativeUniV2SaviourWithdraw');
    // eslint-disable-next-line max-len
    const reflexerSaviourWithdrawAction = new dfs.actions.reflexer.ReflexerNativeUniV2SaviourWithdrawAction(
        to,
        safeId,
        lpTokenAmount,
    );
    const functionData = reflexerSaviourWithdrawAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](reflexerSaviourWithdrawAddress, functionData, { gasLimit: 3000000 });
};

const claimInstMaker = async (proxy, index, vaultId, reward, networth, merkle, owner, to) => {
    const claimInstMakerAddress = await getAddrFromRegistry('ClaimInstMaker');
    const claimInstMakerAction = new dfs.actions.insta.ClaimInstMakerAction(
        index, vaultId, reward, networth, merkle, owner, to,
    );
    const functionData = claimInstMakerAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](claimInstMakerAddress, functionData);
};

const balancerSupply = async (proxy, poolId, from, to, tokens, maxAmountsIn, userData) => {
    const balancerSupplyAddress = await getAddrFromRegistry('BalancerV2Supply');
    const balancerSupplyAction = new dfs.actions.balancer.BalancerV2SupplyAction(
        poolId, from, to, tokens, maxAmountsIn, userData,
    );
    const functionData = balancerSupplyAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](balancerSupplyAddress, functionData);
};

const balancerClaim = async (proxy, liquidityProvider, to, weeks, balances, merkleProofs) => {
    const balancerClaimAddress = await getAddrFromRegistry('BalancerV2Claim');
    const balancerClaimAction = new dfs.actions.balancer.BalancerV2ClaimAction(
        liquidityProvider, to, weeks, balances, merkleProofs,
    );
    const functionData = balancerClaimAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](balancerClaimAddress, functionData);
};

const balancerWithdraw = async (
    proxy,
    poolId,
    from,
    to,
    lpTokenAmount,
    tokens,
    minAmountsOut,
    userData,
) => {
    const balancerWithdrawAddress = await getAddrFromRegistry('BalancerV2Withdraw');
    const balancerWithdrawAction = new dfs.actions.balancer.BalancerV2WithdrawAction(
        poolId,
        from,
        to,
        lpTokenAmount,
        tokens,
        minAmountsOut,
        userData,
    );
    const functionData = balancerWithdrawAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](balancerWithdrawAddress, functionData);
};

const changeProxyOwner = async (proxy, newOwner) => {
    const changeProxyOwnerAddress = await getAddrFromRegistry('ChangeProxyOwner');
    const changeProxyOwnerAction = new dfs.actions.basic.ChangeProxyOwnerAction(
        newOwner,
    );
    const functionData = changeProxyOwnerAction.encodeForDsProxyCall()[1];
    return proxy['execute(address,bytes)'](changeProxyOwnerAddress, functionData);
};

const curveSwap = async (proxy, sender, receiver, pool, from, to, amount, expected) => {
    const curveSwapAddr = await getAddrFromRegistry('CurveSwap');

    const curveSwapAction = new dfs.actions.curve.CurveSwapAction(
        sender, receiver, pool, from, to, amount, expected,
    );

    const functionData = curveSwapAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](curveSwapAddr, functionData, { gasLimit: 3000000 });
};

const curveDeposit = async (
    proxy,
    sender,
    receiver,
    depositTarget,
    lpToken,
    minMintAmount,
    amounts,
    tokens,
    useUnderlying,
) => {
    const curveDepositAddr = await getAddrFromRegistry('CurveDeposit');

    const curveDepositAction = new dfs.actions.curve.CurveDepositAction(
        sender, receiver, depositTarget, lpToken, minMintAmount, amounts, tokens, useUnderlying,
    );

    const functionData = curveDepositAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](curveDepositAddr, functionData, { gasLimit: 3000000 });
};

const curveWithdraw = async (
    proxy,
    sender,
    receiver,
    pool,
    lpToken,
    burnAmount,
    minAmounts,
    tokens,
    useUnderlying,
) => {
    const curveWithdrawAddr = await getAddrFromRegistry('CurveWithdraw');

    const curveWithdrawAction = new dfs.actions.curve.CurveWithdrawAction(
        sender, receiver, pool, lpToken, burnAmount, minAmounts, tokens, useUnderlying,
    );

    const functionData = curveWithdrawAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](curveWithdrawAddr, functionData, { gasLimit: 3000000 });
};

// eslint-disable-next-line max-len
const curveWithdrawImbalance = async (proxy, sender, receiver, pool, lpToken, maxBurnAmount, amounts) => {
    const curveWithdrawImbalanceAddr = await getAddrFromRegistry('CurveWithdrawImbalance');

    const curveWithdrawImbalanceAction = new dfs.actions.curve.CurveWithdrawImbalanceAction(
        sender, receiver, pool, lpToken, maxBurnAmount, amounts,
    );

    const functionData = curveWithdrawImbalanceAction.encodeForDsProxyCall()[1];

    return proxy['execute(address,bytes)'](curveWithdrawImbalanceAddr, functionData, { gasLimit: 3000000 });
};

module.exports = {
    sell,
    buy,

    openMcd,
    supplyMcd,
    generateMcd,
    paybackMcd,
    withdrawMcd,
    openVault,
    mcdGive,
    mcdMerge,

    supplyAave,
    withdrawAave,
    borrowAave,
    paybackAave,
    claimStkAave,

    supplyComp,
    withdrawComp,
    borrowComp,
    paybackComp,
    claimComp,

    uniSupply,
    uniWithdraw,

    reflexerOpen,
    reflexerSupply,
    reflexerWithdraw,
    reflexerPayback,
    reflexerGenerate,
    reflexerSaviourDeposit,
    reflexerSaviourWithdraw,

    liquityOpen,
    liquityBorrow,
    liquityPayback,
    liquitySupply,
    liquityWithdraw,
    liquityClose,
    liquityRedeem,
    liquityStake,
    liquityUnstake,
    liquitySPDeposit,
    liquitySPWithdraw,
    liquityEthGainToTrove,

    uniV3Mint,
    uniV3Supply,
    uniV3Withdraw,
    uniV3Collect,
    uniV3CreatePool,

    dydxSupply,
    dydxWithdraw,

    yearnSupply,
    yearnWithdraw,

    lidoStake,

    curveSwap,
    curveDeposit,
    curveWithdraw,
    curveWithdrawImbalance,

    buyTokenIfNeeded,
    claimInstMaker,

    balancerSupply,
    balancerWithdraw,
    balancerClaim,

    changeProxyOwner,
};
