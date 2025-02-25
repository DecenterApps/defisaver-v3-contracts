// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultResolver } from "../interfaces/fluid/resolvers/IFluidVaultResolver.sol";
import { IFluidLendingResolver } from "../interfaces/fluid/resolvers/IFluidLendingResolver.sol";
import { FluidRatioHelper } from "../../contracts/actions/fluid/helpers/FluidRatioHelper.sol";
import { IERC20 } from "../interfaces/IERC20.sol";

/// @title FluidView - aggregate various information about Fluid vaults and users
contract FluidView is FluidRatioHelper {

    struct UserPosition {
        uint256 nftId;
        address owner;
        bool isLiquidated;
        bool isSupplyPosition;
        uint256 supply;
        uint256 borrow;
        uint256 ratio;
        int256 tick;
        uint256 tickId;
    }

    struct VaultData {
        address vault; // address of the vault
        uint256 vaultId; // unique id of the vault
        uint256 vaultType; // 10000 = Vault(1 coll / 1 debt), 20000 = 2/1, 30000 = 1/2, 40000 = 2/2
        bool isSmartColl; // smart collateral vaults have 2 tokens as collateral
        bool isSmartDebt; // smart debt vaults have 2 tokens as debt
        address supplyToken0; // always present
        address supplyToken1; // only used for smart collateral vaults
        address borrowToken0; // always present
        address borrowToken1; // only used for smart debt vaults
        uint256 supplyToken0Decimals; // decimals of the collateral token 0
        uint256 supplyToken1Decimals; // decimals of the collateral token 1. 0 if not present
        uint256 borrowToken0Decimals; // decimals of the debt token 0
        uint256 borrowToken1Decimals; // decimals of the debt token 1. 0 if not present
        uint16 collateralFactor; // e.g 8500 = 85%
        uint16 liquidationThreshold; // e.g 9000 = 90%
        uint16 liquidationMaxLimit;  // LML is the threshold above which 100% of your position gets liquidated instantly
        uint16 withdrawalGap; // Safety non-withdrawable amount to guarantee liquidations. E.g 500 = 5%
        uint16 liquidationPenalty; // e.g 100 = 1%, 500 = 5%
        uint16 borrowFee;
        address oracle; // address of the oracle
        uint256 oraclePriceOperate;
        uint256 oraclePriceLiquidate;
        uint256 vaultSupplyExchangePrice;
        uint256 vaultBorrowExchangePrice;
        int256 supplyRateVault;
        int256 borrowRateVault;
        int256 rewardsOrFeeRateSupply;
        int256 rewardsOrFeeRateBorrow;
        uint256 totalPositions; // Total positions in the vault
        uint256 totalSupplyVault; // Total supplied assets to the vault
        uint256 totalBorrowVault; // Total borrowed assets from the vault
        uint256 withdrawalLimit; // The limit until where you can withdraw. If 0, all users can withdraw
        uint256 withdrawableUntilLimit; // The amount that can be withdrawn until the limit
        uint256 withdrawable; // min(supply - withdrawalGap - currentLimit, availableBalance)
        uint256 baseWithdrawalLimit; // The minimum limit for a vault's withdraw. The further expansion happens on this base
        uint256 withdrawExpandPercent; // The rate at which limits would increase or decrease over the given duration. E.g 2500 = 25%
        uint256 withdrawExpandDuration; // The time for which the limits expand at the given rate (in seconds)
        uint256 borrowLimit; // The limit until where user can borrow
        uint256 borrowableUntilLimit; // borrowable amount until any borrow limit (incl. max utilization limit)
        uint256 borrowable; // min(currentLimit - borrow, borrowableMaxUtilization - borrow, availableBalance)
        uint256 borrowLimitUtilization;  // Total borrow limit for the maximum allowed utilization
        uint256 maxBorrowLimit; // The maximum limit for a vault above which it is not possible to borrow
        uint256 borrowExpandPercent; // The rate at which limits would increase or decrease over the given duration. E.g 2500 = 25%
        uint256 borrowExpandDuration; // The time for which the limits expand at the given rate (in seconds)
        uint256 baseBorrowLimit; // The minimum limit for a vault's borrow. The further expansion happens on this base
        uint256 minimumBorrowing; // The minimum amount that can be borrowed from the vault
    }
    
    struct NftWithVault {
        uint256 nftId;
        uint256 vaultId;
        address vaultAddr;
    }

    struct UserEarnPosition {
        uint256 fTokenShares;
        uint256 underlyingAssets;
        uint256 underlyingBalance;
        uint256 allowance;
    }

    struct FTokenData {
        address tokenAddress;
        bool isNativeUnderlying;
        string name;
        string symbol;
        uint256 decimals;
        address asset;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 convertToShares;
        uint256 convertToAssets;
        uint256 rewardsRate; // additional yield from rewards, if active
        uint256 supplyRate; // yield at Liquidity
        uint256 withdrawable; // actual currently withdrawable amount (supply - withdrawal Limit) & considering balance
        bool modeWithInterest; // true if mode = with interest, false = without interest
        uint256 expandPercent; // withdrawal limit expand percent in 1e2
        uint256 expandDuration; // withdrawal limit expand duration in seconds
    }

    /// @notice Get all user positions with vault data
    function getUserPositions(address _user) 
        external view returns (UserPosition[] memory positions, VaultData[] memory vaults) 
    {
        uint256[] memory nftIds = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionsNftIdOfUser(_user);

        positions = new UserPosition[](nftIds.length);
        vaults = new VaultData[](nftIds.length);

        for (uint256 i = 0; i < nftIds.length; i++) {
            (positions[i], vaults[i]) = getPositionByNftId(nftIds[i]);
        }

        return (positions, vaults);
    }

    /// @notice Get all nftIds for a specific user
    function getUserNftIds(address _user) external view returns (uint256[] memory) {
        return IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionsNftIdOfUser(_user);
    }

    /// @notice Get all nftIds with vaultIds for a specific user
    function getUserNftIdsWithVaultIds(address _user) external view returns (NftWithVault[] memory retVal) {
        uint256[] memory nftIds = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionsNftIdOfUser(_user);
        retVal = new NftWithVault[](nftIds.length);

        for (uint256 i = 0; i < nftIds.length; i++) {
            address vaultByNft = IFluidVaultResolver(FLUID_VAULT_RESOLVER).vaultByNftId(nftIds[i]);
            uint256 vaultId = IFluidVaultResolver(FLUID_VAULT_RESOLVER).getVaultId(vaultByNft);

            retVal[i] = NftWithVault({
                nftId: nftIds[i],
                vaultId: vaultId,
                vaultAddr: vaultByNft
            });
        }
    }

    /// @notice Get position data with vault data for a specific nftId
    function getPositionByNftId(uint256 _nftId) public view returns (UserPosition memory position, VaultData memory vault) {
        (
            IFluidVaultResolver.UserPosition memory userPosition,
            IFluidVaultResolver.VaultEntireData memory vaultData
        ) = IFluidVaultResolver(FLUID_VAULT_RESOLVER).positionByNftId(_nftId);

        position = UserPosition({
            nftId: userPosition.nftId,
            owner: userPosition.owner,
            isLiquidated: userPosition.isLiquidated,
            isSupplyPosition: userPosition.isSupplyPosition,
            supply: userPosition.supply,
            borrow: userPosition.borrow,
            ratio: getRatio(userPosition.nftId),
            tick: userPosition.tick,
            tickId: userPosition.tickId
        });

        vault = getVaultData(vaultData.vault);
    }

    /// @notice Get vault data for a specific vault address
    function getVaultData(address _vault) public view returns (VaultData memory vaultData) {
        IFluidVaultResolver.VaultEntireData memory data = 
            IFluidVaultResolver(FLUID_VAULT_RESOLVER).getVaultEntireData(_vault);

        address supplyToken0 = data.constantVariables.supplyToken.token0;
        address supplyToken1 = data.constantVariables.supplyToken.token1;
        address borrowToken0 = data.constantVariables.borrowToken.token0;
        address borrowToken1 = data.constantVariables.borrowToken.token1;

        vaultData = VaultData({
            vault: _vault,
            vaultId: data.constantVariables.vaultId,
            vaultType: data.constantVariables.vaultType,
            isSmartColl: data.isSmartCol,
            isSmartDebt: data.isSmartDebt,
            
            supplyToken0: supplyToken0,
            supplyToken1: supplyToken1,
            borrowToken0: borrowToken0,
            borrowToken1: borrowToken1,

            supplyToken0Decimals: supplyToken0 != ETH_ADDR ? IERC20(supplyToken0).decimals() : 18,
            supplyToken1Decimals: supplyToken1 != address(0) ? (supplyToken1 != ETH_ADDR ? IERC20(supplyToken1).decimals() : 18) : 0,
            borrowToken0Decimals: borrowToken0 != ETH_ADDR ? IERC20(borrowToken0).decimals(): 18,
            borrowToken1Decimals: borrowToken1 != address(0) ? (borrowToken1 != ETH_ADDR ? IERC20(borrowToken1).decimals() : 18) : 0,

            collateralFactor: data.configs.collateralFactor,
            liquidationThreshold: data.configs.liquidationThreshold,
            liquidationMaxLimit: data.configs.liquidationMaxLimit,
            withdrawalGap: data.configs.withdrawalGap,
            liquidationPenalty: data.configs.liquidationPenalty,
            borrowFee: data.configs.borrowFee,
            oracle: data.configs.oracle,
            oraclePriceOperate: data.configs.oraclePriceOperate,
            oraclePriceLiquidate: data.configs.oraclePriceLiquidate,

            vaultSupplyExchangePrice: data.exchangePricesAndRates.vaultSupplyExchangePrice,
            vaultBorrowExchangePrice: data.exchangePricesAndRates.vaultBorrowExchangePrice,
            supplyRateVault: data.exchangePricesAndRates.supplyRateVault,
            borrowRateVault: data.exchangePricesAndRates.borrowRateVault,
            rewardsOrFeeRateSupply: data.exchangePricesAndRates.rewardsOrFeeRateSupply,
            rewardsOrFeeRateBorrow: data.exchangePricesAndRates.rewardsOrFeeRateBorrow,

            totalPositions: data.vaultState.totalPositions,

            totalSupplyVault: data.totalSupplyAndBorrow.totalSupplyVault,
            totalBorrowVault: data.totalSupplyAndBorrow.totalBorrowVault,

            withdrawalLimit: data.liquidityUserSupplyData.withdrawalLimit,
            withdrawableUntilLimit: data.liquidityUserSupplyData.withdrawableUntilLimit,
            withdrawable: data.liquidityUserSupplyData.withdrawable,
            baseWithdrawalLimit: data.liquidityUserSupplyData.baseWithdrawalLimit,
            withdrawExpandPercent: data.liquidityUserSupplyData.expandPercent,
            withdrawExpandDuration: data.liquidityUserSupplyData.expandDuration,

            borrowLimit: data.liquidityUserBorrowData.borrowLimit,
            borrowableUntilLimit: data.liquidityUserBorrowData.borrowableUntilLimit,
            borrowable: data.liquidityUserBorrowData.borrowable,
            borrowLimitUtilization: data.liquidityUserBorrowData.borrowLimitUtilization,
            maxBorrowLimit: data.liquidityUserBorrowData.maxBorrowLimit,
            borrowExpandPercent: data.liquidityUserBorrowData.expandPercent,
            borrowExpandDuration: data.liquidityUserBorrowData.expandDuration,
            baseBorrowLimit: data.liquidityUserBorrowData.baseBorrowLimit,

            minimumBorrowing: data.limitsAndAvailability.minimumBorrowing
        });
    }

    /*//////////////////////////////////////////////////////////////
                        FLUID EARN - F TOKENs UTILS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get all fTokens addresses
    function getAllFTokens() external view returns (address[] memory) {
        return IFluidLendingResolver(FLUID_LENDING_RESOLVER).getAllFTokens();
    }

    /// @notice Get fToken data for a specific fToken address
    function getFTokenData(address _fToken) public view returns (FTokenData memory fTokenData) {
        
        IFluidLendingResolver.FTokenDetails memory details;

        // Fluid Lending Resolver checks if the fToken's underlying asset supports EIP-2612.
        // For WETH, this triggers the fallback function, which attempts a deposit.
        // This panics because of write protection and consumes all gas, leaving only 1/64th for the caller (EIP-150).
        // To lower the gas cost, we cap the gas limit at 9M, ensuring ~140k gas remains for fetching fWETH details
        // and enough gas is left for further operations within the same block.
        // For arbitrum, we don't need to cap as WETH will have EIP-2612 support.
        if (_fToken == F_WETH_TOKEN_ADDR && block.chainid != 42161) {
            details = IFluidLendingResolver(FLUID_LENDING_RESOLVER).getFTokenDetails{ gas: 9_000_000 }(_fToken);
        } else {
            details = IFluidLendingResolver(FLUID_LENDING_RESOLVER).getFTokenDetails(_fToken);
        }
        
        fTokenData = _filterFTokenData(details);
    }

    /// @notice Get fToken data for all fTokens
    function getAllFTokensData() public view returns (FTokenData[] memory) {
        address[] memory fTokens = IFluidLendingResolver(FLUID_LENDING_RESOLVER).getAllFTokens();
        FTokenData[] memory fTokenData = new FTokenData[](fTokens.length);

        for (uint256 i = 0; i < fTokens.length; i++) {
            fTokenData[i] = getFTokenData(fTokens[i]);
        } 

        return fTokenData;
    }

    /// @notice Get user position for a specific fToken address
    function getUserEarnPosition(address _fToken, address _user) public view returns (UserEarnPosition memory) {
        IFluidLendingResolver.UserPosition memory data = 
            IFluidLendingResolver(FLUID_LENDING_RESOLVER).getUserPosition(_fToken, _user);

        return UserEarnPosition({
            fTokenShares: data.fTokenShares,
            underlyingAssets: data.underlyingAssets,
            underlyingBalance: data.underlyingBalance,
            allowance: data.allowance
        });
    }

    /// @notice Get user position for a specific fToken address
    function getUserEarnPositionWithFToken(
        address _fToken,
        address _user
    ) public view returns (UserEarnPosition memory userPosition, FTokenData memory fTokenData) {
        IFluidLendingResolver.UserPosition memory userData = 
            IFluidLendingResolver(FLUID_LENDING_RESOLVER).getUserPosition(_fToken, _user);

        userPosition = UserEarnPosition({
            fTokenShares: userData.fTokenShares,
            underlyingAssets: userData.underlyingAssets,
            underlyingBalance: userData.underlyingBalance,
            allowance: userData.allowance
        });

        fTokenData = getFTokenData(_fToken);
    }

    /// @notice Get user positions for all fTokens
    function getAllUserEarnPositionsWithFTokens(address _user)
        external
        view
        returns (UserEarnPosition[] memory userPositions, FTokenData[] memory fTokensData)
    {
        fTokensData = getAllFTokensData();

        userPositions = new UserEarnPosition[](fTokensData.length);

        for (uint256 i = 0; i < fTokensData.length; i++) {
            userPositions[i] = getUserEarnPosition(fTokensData[i].tokenAddress, _user);
        }
    }

    /// @notice Helper function to filter FTokenDetails to FTokenData
    function _filterFTokenData(
        IFluidLendingResolver.FTokenDetails memory _details
    ) internal pure returns (FTokenData memory fTokenData) {
        fTokenData = FTokenData({
            tokenAddress: _details.tokenAddress,
            isNativeUnderlying: _details.isNativeUnderlying,
            name: _details.name,
            symbol: _details.symbol,
            decimals: _details.decimals,
            asset: _details.asset,
            totalAssets: _details.totalAssets,
            totalSupply: _details.totalSupply,
            convertToShares: _details.convertToShares,
            convertToAssets: _details.convertToAssets,
            rewardsRate: _details.rewardsRate,
            supplyRate: _details.supplyRate,
            withdrawable: _details.liquidityUserSupplyData.withdrawable,
            modeWithInterest: _details.liquidityUserSupplyData.modeWithInterest,
            expandPercent: _details.liquidityUserSupplyData.expandPercent,
            expandDuration: _details.liquidityUserSupplyData.expandDuration
        });
    }
}