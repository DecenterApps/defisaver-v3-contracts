// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity =0.8.24;

import { IFluidDexT1 } from "../IFluidDexT1.sol";
import { IFluidLiquidityResolverStructs } from "./IFluidLiquidityResolverStructs.sol";

interface IFluidDexResolver {

    struct DexState {
        uint256 lastToLastStoredPrice;
        uint256 lastStoredPrice; // price of pool after the most recent swap
        uint256 centerPrice;
        uint256 lastUpdateTimestamp;
        uint256 lastPricesTimeDiff;
        uint256 oracleCheckPoint;
        uint256 oracleMapping;
        uint256 totalSupplyShares;
        uint256 totalBorrowShares;
        bool isSwapAndArbitragePaused; // if true, only perfect functions will be usable
        ShiftChanges shifts;
        // below values have to be combined with Oracle price data at the VaultResolver
        uint256 token0PerSupplyShare; // token0 amount per 1e18 supply shares
        uint256 token1PerSupplyShare; // token1 amount per 1e18 supply shares
        uint256 token0PerBorrowShare; // token0 amount per 1e18 borrow shares
        uint256 token1PerBorrowShare; // token1 amount per 1e18 borrow shares
    }

    struct ShiftData {
        uint256 oldUpper;
        uint256 oldLower;
        uint256 duration;
        uint256 startTimestamp;
        uint256 oldTime; // only for thresholdShift
    }

    struct CenterPriceShift {
        uint256 shiftPercentage;
        uint256 duration;
        uint256 startTimestamp;
    }

    struct ShiftChanges {
        bool isRangeChangeActive;
        bool isThresholdChangeActive;
        bool isCenterPriceShiftActive;
        ShiftData rangeShift;
        ShiftData thresholdShift;
        CenterPriceShift centerPriceShift;
    }

    struct Configs {
        bool isSmartCollateralEnabled;
        bool isSmartDebtEnabled;
        uint256 fee;
        uint256 revenueCut;
        uint256 upperRange;
        uint256 lowerRange;
        uint256 upperShiftThreshold;
        uint256 lowerShiftThreshold;
        uint256 shiftingTime;
        address centerPriceAddress;
        address hookAddress;
        uint256 maxCenterPrice;
        uint256 minCenterPrice;
        uint256 utilizationLimitToken0;
        uint256 utilizationLimitToken1;
        uint256 maxSupplyShares;
        uint256 maxBorrowShares;
    }

    // @dev note there might be other things that act as effective limits which are not fully considered here.
    // e.g. such as maximum 5% oracle shift in one swap, withdraws & borrowing together affecting each other,
    // shares being below max supply / borrow shares etc.
    struct SwapLimitsAndAvailability {
        // liquidity total amounts
        uint liquiditySupplyToken0;
        uint liquiditySupplyToken1;
        uint liquidityBorrowToken0;
        uint liquidityBorrowToken1;
        // liquidity limits
        uint liquidityWithdrawableToken0;
        uint liquidityWithdrawableToken1;
        uint liquidityBorrowableToken0;
        uint liquidityBorrowableToken1;
        // utilization limits based on config at Dex. (e.g. liquiditySupplyToken0 * Configs.utilizationLimitToken0 / 1e3)
        uint utilizationLimitToken0;
        uint utilizationLimitToken1;
        // swappable amounts until utilization limit.
        // In a swap that does both withdraw and borrow, the effective amounts might be less because withdraw / borrow affect each other
        // (both increase utilization).
        uint withdrawableUntilUtilizationLimitToken0; // x = totalSupply - totalBorrow / maxUtilizationPercentage
        uint withdrawableUntilUtilizationLimitToken1;
        uint borrowableUntilUtilizationLimitToken0; // x = maxUtilizationPercentage * totalSupply - totalBorrow.
        uint borrowableUntilUtilizationLimitToken1;
        // additional liquidity related data such as supply amount, limits, expansion etc.
        IFluidLiquidityResolverStructs.UserSupplyData liquidityUserSupplyDataToken0;
        IFluidLiquidityResolverStructs.UserSupplyData liquidityUserSupplyDataToken1;
        // additional liquidity related data such as borrow amount, limits, expansion etc.
        IFluidLiquidityResolverStructs.UserBorrowData liquidityUserBorrowDataToken0;
        IFluidLiquidityResolverStructs.UserBorrowData liquidityUserBorrowDataToken1;
        // liquidity token related data
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData0;
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData1;
    }

    struct DexEntireData {
        address dex;
        IFluidDexT1.ConstantViews constantViews;
        IFluidDexT1.ConstantViews2 constantViews2;
        Configs configs;
        IFluidDexT1.PricesAndExchangePrice pex;
        IFluidDexT1.CollateralReserves colReserves;
        IFluidDexT1.DebtReserves debtReserves;
        DexState dexState;
        SwapLimitsAndAvailability limitsAndAvailability;
    }

    // amounts are always in normal (for withInterest already multiplied with exchange price)
    struct UserSupplyData {
        bool isAllowed;
        uint256 supply; // user supply amount/shares
        // the withdrawal limit (e.g. if 10% is the limit, and 100M is supplied, it would be 90M)
        uint256 withdrawalLimit;
        uint256 lastUpdateTimestamp;
        uint256 expandPercent; // withdrawal limit expand percent in 1e2
        uint256 expandDuration; // withdrawal limit expand duration in seconds
        uint256 baseWithdrawalLimit;
        // the current actual max withdrawable amount (e.g. if 10% is the limit, and 100M is supplied, it would be 10M)
        uint256 withdrawableUntilLimit;
        uint256 withdrawable; // actual currently withdrawable amount (supply - withdrawal Limit) & considering balance
        // liquidity related data such as supply amount, limits, expansion etc.
        IFluidLiquidityResolverStructs.UserSupplyData liquidityUserSupplyDataToken0;
        IFluidLiquidityResolverStructs.UserSupplyData liquidityUserSupplyDataToken1;
        // liquidity token related data
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData0;
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData1;
    }

    // amounts are always in normal (for withInterest already multiplied with exchange price)
    struct UserBorrowData {
        bool isAllowed;
        uint256 borrow; // user borrow amount/shares
        uint256 borrowLimit;
        uint256 lastUpdateTimestamp;
        uint256 expandPercent;
        uint256 expandDuration;
        uint256 baseBorrowLimit;
        uint256 maxBorrowLimit;
        uint256 borrowableUntilLimit; // borrowable amount until any borrow limit (incl. max utilization limit)
        uint256 borrowable; // actual currently borrowable amount (borrow limit - already borrowed) & considering balance, max utilization
        // liquidity related data such as borrow amount, limits, expansion etc.
        IFluidLiquidityResolverStructs.UserBorrowData liquidityUserBorrowDataToken0;
        IFluidLiquidityResolverStructs.UserBorrowData liquidityUserBorrowDataToken1;
        // liquidity token related data
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData0;
        IFluidLiquidityResolverStructs.OverallTokenData liquidityTokenData1;
    }    

    /// @notice Get the entire data for a DEX
    /// @param dex_ The address of the DEX
    /// @return data_ A struct containing all the data for the DEX
    /// @dev expected to be called via callStatic
    function getDexEntireData(address dex_) external returns (DexEntireData memory data_);

    /// @dev Estimate deposit tokens in equal proportion to the current pool ratio
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to mint
    /// @param maxToken0Deposit_ Maximum amount of token0 to deposit
    /// @param maxToken1Deposit_ Maximum amount of token1 to deposit
    /// @return token0Amt_ Estimated amount of token0 to deposit
    /// @return token1Amt_ Estimated amount of token1 to deposit
    function estimateDepositPerfect(
        address dex_,
        uint shares_,
        uint maxToken0Deposit_,
        uint maxToken1Deposit_
    ) external payable returns (uint token0Amt_, uint token1Amt_);

    /// @dev Estimate withdrawal of a perfect amount of collateral liquidity
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to withdraw
    /// @param minToken0Withdraw_ The minimum amount of token0 the user is willing to accept
    /// @param minToken1Withdraw_ The minimum amount of token1 the user is willing to accept
    /// @return token0Amt_ Estimated amount of token0 to be withdrawn
    /// @return token1Amt_ Estimated amount of token1 to be withdrawn
    function estimateWithdrawPerfect(
        address dex_,
        uint shares_,
        uint minToken0Withdraw_,
        uint minToken1Withdraw_
    ) external returns (uint token0Amt_, uint token1Amt_);


    /// @dev Estimate borrowing tokens in equal proportion to the current debt pool ratio
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to borrow
    /// @param minToken0Borrow_ Minimum amount of token0 to borrow
    /// @param minToken1Borrow_ Minimum amount of token1 to borrow
    /// @return token0Amt_ Estimated amount of token0 to be borrowed
    /// @return token1Amt_ Estimated amount of token1 to be borrowed
    function estimateBorrowPerfect(
        address dex_,
        uint shares_,
        uint minToken0Borrow_,
        uint minToken1Borrow_
    ) external returns (uint token0Amt_, uint token1Amt_);

    /// @dev Estimate paying back borrowed tokens in equal proportion to the current debt pool ratio
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to pay back
    /// @param maxToken0Payback_ Maximum amount of token0 to pay back
    /// @param maxToken1Payback_ Maximum amount of token1 to pay back
    /// @return token0Amt_ Estimated amount of token0 to be paid back
    /// @return token1Amt_ Estimated amount of token1 to be paid back
    function estimatePaybackPerfect(
        address dex_,
        uint shares_,
        uint maxToken0Payback_,
        uint maxToken1Payback_
    ) external payable returns (uint token0Amt_, uint token1Amt_);

    /// @dev Estimate deposit of tokens
    /// @param dex_ The address of the DEX contract
    /// @param token0Amt_ Amount of token0 to deposit
    /// @param token1Amt_ Amount of token1 to deposit
    /// @param minSharesAmt_ Minimum amount of shares to receive
    /// @return shares_ Estimated amount of shares to be minted
    function estimateDeposit(
        address dex_,
        uint token0Amt_,
        uint token1Amt_,
        uint minSharesAmt_
    ) external payable returns (uint shares_);

    /// @dev Estimate withdrawal of tokens
    /// @param dex_ The address of the DEX contract
    /// @param token0Amt_ Amount of token0 to withdraw
    /// @param token1Amt_ Amount of token1 to withdraw
    /// @param maxSharesAmt_ Maximum amount of shares to burn
    /// @return shares_ Estimated amount of shares to be burned
    function estimateWithdraw(
        address dex_,
        uint token0Amt_,
        uint token1Amt_,
        uint maxSharesAmt_
    ) external returns (uint shares_);

    /// @dev Estimate borrowing of tokens
    /// @param dex_ The address of the DEX contract
    /// @param token0Amt_ Amount of token0 to borrow
    /// @param token1Amt_ Amount of token1 to borrow
    /// @param maxSharesAmt_ Maximum amount of shares to mint
    /// @return shares_ Estimated amount of shares to be minted
    function estimateBorrow(
        address dex_,
        uint token0Amt_,
        uint token1Amt_,
        uint maxSharesAmt_
    ) external returns (uint shares_);

    /// @dev Estimate paying back of borrowed tokens
    /// @param dex_ The address of the DEX contract
    /// @param token0Amt_ Amount of token0 to pay back
    /// @param token1Amt_ Amount of token1 to pay back
    /// @param minSharesAmt_ Minimum amount of shares to burn
    /// @return shares_ Estimated amount of shares to be burned
    function estimatePayback(
        address dex_,
        uint token0Amt_,
        uint token1Amt_,
        uint minSharesAmt_
    ) external payable returns (uint shares_);

    /// @dev Estimate withdrawal of a perfect amount of collateral liquidity in one token
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to withdraw
    /// @param minToken0_ The minimum amount of token0 the user is willing to accept
    /// @param minToken1_ The minimum amount of token1 the user is willing to accept
    /// @return withdrawAmt_ Estimated amount of tokens to be withdrawn
    function estimateWithdrawPerfectInOneToken(
        address dex_,
        uint shares_,
        uint minToken0_,
        uint minToken1_
    ) external returns (uint withdrawAmt_);

    /// @dev Estimate paying back of a perfect amount of borrowed tokens in one token
    /// @param dex_ The address of the DEX contract
    /// @param shares_ The number of shares to pay back
    /// @param maxToken0_ Maximum amount of token0 to pay back
    /// @param maxToken1_ Maximum amount of token1 to pay back
    /// @return paybackAmt_ Estimated amount of tokens to be paid back
    function estimatePaybackPerfectInOneToken(
        address dex_,
        uint shares_,
        uint maxToken0_,
        uint maxToken1_
    ) external payable returns (uint paybackAmt_);
}