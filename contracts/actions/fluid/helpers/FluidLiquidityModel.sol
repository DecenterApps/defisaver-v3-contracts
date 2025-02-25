// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

import { IFluidVaultResolver } from "../../../interfaces/fluid/resolvers/IFluidVaultResolver.sol";

/// @title Helper library containing data structs used for interaction with Fluid liquidity layer
library FluidLiquidityModel {

    /// @notice Data struct for supplying liquidity to a Fluid liquidity layer
    /// @param vault Address of the vault
    /// @param vaultType Type of the vault. For supply, it will be T1 or T3
    /// @param nftId NFT id of the position
    /// @param supplyToken Address of the supply token
    /// @param amount Amount of tokens to supply
    /// @param from Address to pull the tokens from
    /// Fields used only when opening a new position, where we also need to know the debt amount.
    /// Used only to save gas, as this way we don't need separate calls for supply and borrow.
    /// @param debtAmount Amount of debt to be generated
    /// @param debtTo Address to send the debt to
    struct SupplyData {
        address vault;
        uint256 vaultType;
        uint256 nftId;
        address supplyToken;
        uint256 amount;
        address from;
        uint256 debtAmount;
        address debtTo;
    }

    /// @notice Data struct for withdrawing liquidity from a Fluid liquidity layer
    /// @param vault Address of the vault
    /// @param vaultType Type of the vault. For withdraw, it will be T1 or T3
    /// @param nftId NFT id of the position
    /// @param supplyToken Address of the supply token
    /// @param amount Amount of tokens to withdraw
    /// @param to Address to send the tokens to
    /// @param wrapWithdrawnEth Whether to wrap withdrawn ETH into WETH
    struct WithdrawData {
        address vault;
        uint256 vaultType;
        uint256 nftId;
        address supplyToken;
        uint256 amount;
        address to;
        bool wrapWithdrawnEth;
    }

    /// @notice Data struct for borrowing tokens from a Fluid liquidity layer
    /// @param vault Address of the vault
    /// @param vaultType Type of the vault. For borrow, it will be T1 or T2
    /// @param nftId NFT id of the position
    /// @param borrowToken Address of the borrow token
    /// @param amount Amount of tokens to borrow
    /// @param to Address to send the borrowed tokens to
    /// @param wrapBorrowedEth Whether to wrap borrowed ETH into WETH
    struct BorrowData {
        address vault;
        uint256 vaultType;
        uint256 nftId;
        address borrowToken;
        uint256 amount;
        address to;
        bool wrapBorrowedEth;
    }

    /// @notice Data struct for paying back borrowed tokens to a Fluid liquidity layer
    /// @param vault Address of the vault
    /// @param vaultType Type of the vault. For payback, it will be T1 or T2
    /// @param nftId NFT id of the position
    /// @param borrowToken Address of the borrow token
    /// @param amount Amount of tokens to pay back
    /// @param from Address to pull the tokens from
    /// @param position User position data fetched from Fluid Vault Resolver
    struct PaybackData {
        address vault;
        uint256 vaultType;
        uint256 nftId;
        address borrowToken;
        uint256 amount;
        address from;
        IFluidVaultResolver.UserPosition position;
    }
}