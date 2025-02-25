// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity =0.8.24;

interface IFluidVaultT1 {

    /// @notice emitted when an operate() method is executed that changes collateral (`colAmt_`) / debt (debtAmt_`)
    /// amount for a `user_` position with `nftId_`. Receiver of any funds is the address `to_`.
    event LogOperate(address user_, uint256 nftId_, int256 colAmt_, int256 debtAmt_, address to_);

    struct ConstantViews {
        address liquidity;
        address factory;
        address adminImplementation;
        address secondaryImplementation;
        address supplyToken;
        address borrowToken;
        uint8 supplyDecimals;
        uint8 borrowDecimals;
        uint256 vaultId;
        bytes32 liquiditySupplyExchangePriceSlot;
        bytes32 liquidityBorrowExchangePriceSlot;
        bytes32 liquidityUserSupplySlot;
        bytes32 liquidityUserBorrowSlot;
    }

    /// @dev Single function which handles supply, withdraw, borrow & payback
    /// @param nftId_ NFT ID for interaction. If 0 then create new NFT/position.
    /// @param newCol_ new collateral. If positive then deposit, if negative then withdraw, if 0 then do nohing
    /// @param newDebt_ new debt. If positive then borrow, if negative then payback, if 0 then do nohing
    /// @param to_ address where withdraw or borrow should go. If address(0) then msg.sender
    /// @return nftId_ if 0 then this returns the newly created NFT Id else returns the same NFT ID
    /// @return newCol_ final supply amount. Mainly if max withdraw using type(int).min then this is useful to get perfect amount else remain same as newCol_
    /// @return newDebt_ final borrow amount. Mainly if max payback using type(int).min then this is useful to get perfect amount else remain same as newDebt_
    function operate(
        uint256 nftId_, // if 0 then new position
        int256 newCol_, // if negative then withdraw
        int256 newDebt_, // if negative then payback
        address to_ // address at which the borrow & withdraw amount should go to. If address(0) then it'll go to msg.sender
    )
        external
        payable
        returns (
            uint256, // nftId_
            int256, // final supply amount. if - then withdraw
            int256 // final borrow amount. if - then payback
        );

    /// @notice returns all Vault constants
    function constantsView() external view returns (ConstantViews memory constantsView_);
}