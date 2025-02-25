// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity =0.8.24;

interface IFluidLendingResolver {

    // amounts are always in normal (for withInterest already multiplied with exchange price)
    struct UserSupplyData {
        bool modeWithInterest; // true if mode = with interest, false = without interest
        uint256 supply; // user supply amount
        // the withdrawal limit (e.g. if 10% is the limit, and 100M is supplied, it would be 90M)
        uint256 withdrawalLimit;
        uint256 lastUpdateTimestamp;
        uint256 expandPercent; // withdrawal limit expand percent in 1e2
        uint256 expandDuration; // withdrawal limit expand duration in seconds
        uint256 baseWithdrawalLimit;
        // the current actual max withdrawable amount (e.g. if 10% is the limit, and 100M is supplied, it would be 10M)
        uint256 withdrawableUntilLimit;
        uint256 withdrawable; // actual currently withdrawable amount (supply - withdrawal Limit) & considering balance
    }

    struct FTokenDetails {
        address tokenAddress;
        bool eip2612Deposits;
        bool isNativeUnderlying;
        string name;
        string symbol;
        uint256 decimals;
        address asset;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 convertToShares;
        uint256 convertToAssets;
        // additional yield from rewards, if active
        uint256 rewardsRate;
        // yield at Liquidity
        uint256 supplyRate;
        // difference between fToken assets & actual deposit at Liquidity. (supplyAtLiquidity - totalAssets).
        // if negative, rewards must be funded to guarantee withdrawal is possible for all users. This happens
        // by executing rebalance().
        int256 rebalanceDifference;
        // liquidity related data such as supply amount, limits, expansion etc.
        UserSupplyData liquidityUserSupplyData;
    }

    struct UserPosition {
        uint256 fTokenShares;
        uint256 underlyingAssets;
        uint256 underlyingBalance;
        uint256 allowance;
    }

    struct FTokenDetailsUserPosition {
        FTokenDetails fTokenDetails;
        UserPosition userPosition;
    }

    /// @notice returns the lending factory address
    function LENDING_FACTORY() external view returns (address);

    /// @notice returns the liquidity resolver address
    function LIQUIDITY_RESOLVER() external view returns (address);

    /// @notice returns all fToken types at the `LENDING_FACTORY`
    function getAllFTokenTypes() external view returns (string[] memory);

    /// @notice returns all created fTokens at the `LENDING_FACTORY`
    function getAllFTokens() external view returns (address[] memory);

    /// @notice reads if a certain `auth_` address is an allowed auth or not. Owner is auth by default.
    function isLendingFactoryAuth(address auth_) external view returns (bool);

    /// @notice reads if a certain `deployer_` address is an allowed deployer or not. Owner is deployer by default.
    function isLendingFactoryDeployer(address deployer_) external view returns (bool);

    /// @notice computes deterministic token address for `asset_` for a lending protocol
    /// @param  asset_      address of the asset
    /// @param  fTokenType_         type of fToken:
    /// - if underlying asset supports EIP-2612, the fToken should be type `EIP2612Deposits`
    /// - otherwise it should use `Permit2Deposits`
    /// - if it's the native token, it should use `NativeUnderlying`
    /// - could be more types available, check `fTokenTypes()`
    /// @return token_      detemrinistic address of the computed token
    function computeFToken(address asset_, string calldata fTokenType_) external view returns (address);

    /// @notice gets all public details for a certain `fToken_`, such as
    /// fToken type, name, symbol, decimals, underlying asset, total amounts, convertTo values, rewards.
    /// Note it also returns whether the fToken supports deposits / mints via EIP-2612, but it is not a 100% guarantee!
    /// To make sure, check for the underlying if it supports EIP-2612 manually.
    /// @param  fToken_     the fToken to get the details for
    /// @return fTokenDetails_  retrieved FTokenDetails struct
    function getFTokenDetails(address fToken_) external view returns (FTokenDetails memory fTokenDetails_);

    /// @notice returns config, rewards and exchange prices data of an fToken.
    /// @param  fToken_ the fToken to get the data for
    /// @return liquidity_ address of the Liquidity contract.
    /// @return lendingFactory_ address of the Lending factory contract.
    /// @return lendingRewardsRateModel_ address of the rewards rate model contract. changeable by LendingFactory auths.
    /// @return permit2_ address of the Permit2 contract used for deposits / mint with signature
    /// @return rebalancer_ address of the rebalancer allowed to execute `rebalance()`
    /// @return rewardsActive_ true if rewards are currently active
    /// @return liquidityBalance_ current Liquidity supply balance of `address(this)` for the underyling asset
    /// @return liquidityExchangePrice_ (updated) exchange price for the underlying assset in the liquidity protocol (without rewards)
    /// @return tokenExchangePrice_ (updated) exchange price between fToken and the underlying assset (with rewards)
    function getFTokenInternalData(
        address fToken_
    )
        external
        view
        returns (
            address liquidity_,
            address lendingFactory_,
            address lendingRewardsRateModel_,
            address permit2_,
            address rebalancer_,
            bool rewardsActive_,
            uint256 liquidityBalance_,
            uint256 liquidityExchangePrice_,
            uint256 tokenExchangePrice_
        );

    /// @notice gets all public details for all itokens, such as
    /// fToken type, name, symbol, decimals, underlying asset, total amounts, convertTo values, rewards
    function getFTokensEntireData() external view returns (FTokenDetails[] memory);

    /// @notice gets all public details for all itokens, such as
    /// fToken type, name, symbol, decimals, underlying asset, total amounts, convertTo values, rewards
    /// and user position for each token
    function getUserPositions(address user_) external view returns (FTokenDetailsUserPosition[] memory);

    /// @notice gets rewards related data: the `rewardsRateModel_` contract and the current `rewardsRate_` for the `fToken_`
    function getFTokenRewards(
        address fToken_
    ) external view returns (address rewardsRateModel_, uint256 rewardsRate_);

    /// @notice gets rewards rate model config constants
    function getFTokenRewardsRateModelConfig(
        address fToken_
    )
        external
        view
        returns (
            uint256 duration_,
            uint256 startTime_,
            uint256 endTime_,
            uint256 startTvl_,
            uint256 maxRate_,
            uint256 rewardAmount_,
            address initiator_
        );

    /// @notice gets a `user_` position for an `fToken_`.
    /// @return userPosition user position struct
    function getUserPosition(
        address fToken_,
        address user_
    ) external view returns (UserPosition memory userPosition);

    /// @notice gets `fToken_` preview amounts for `assets_` or `shares_`.
    /// @return previewDeposit_ preview for deposit of `assets_`
    /// @return previewMint_ preview for mint of `shares_`
    /// @return previewWithdraw_ preview for withdraw of `assets_`
    /// @return previewRedeem_ preview for redeem of `shares_`
    function getPreviews(
        address fToken_,
        uint256 assets_,
        uint256 shares_
    )
        external
        view
        returns (uint256 previewDeposit_, uint256 previewMint_, uint256 previewWithdraw_, uint256 previewRedeem_);
}
