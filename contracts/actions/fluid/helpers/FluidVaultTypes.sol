// SPDX-License-Identifier: MIT

pragma solidity =0.8.24;

/// @title Helper library defining vault types inside the Fluid protocol
library FluidVaultTypes {

    error InvalidVaultType(uint256 vaultType);

    uint256 internal constant T1_VAULT_TYPE = 1e4; // 1_coll:1_debt
    uint256 internal constant T2_VAULT_TYPE = 2e4; // 2_coll:1_debt (smart coll)
    uint256 internal constant T3_VAULT_TYPE = 3e4; // 1_coll:2_debt (smart debt)
    uint256 internal constant T4_VAULT_TYPE = 4e4; // 2_coll:2_debt (smart coll, smart debt)

    function requireLiquidityCollateral(uint256 _vaultType) internal pure {
        if (_vaultType != T1_VAULT_TYPE && _vaultType != T3_VAULT_TYPE) {
            revert InvalidVaultType(_vaultType);
        }
    }

    function requireLiquidityDebt(uint256 _vaultType) internal pure {
        if (_vaultType != T1_VAULT_TYPE && _vaultType != T2_VAULT_TYPE) {
            revert InvalidVaultType(_vaultType);
        }
    }

    function requireSmartCollateral(uint256 _vaultType) internal pure {
        if (_vaultType != T2_VAULT_TYPE && _vaultType != T4_VAULT_TYPE) {
            revert InvalidVaultType(_vaultType);
        }
    }

    function requireSmartDebt(uint256 _vaultType) internal pure {
        if (_vaultType != T3_VAULT_TYPE && _vaultType != T4_VAULT_TYPE) {
            revert InvalidVaultType(_vaultType);
        }
    }

    function requireDexVault(uint256 _vaultType) internal pure {
        if (_vaultType == T1_VAULT_TYPE) {
            revert InvalidVaultType(_vaultType);
        }
    }

    function isT1Vault(uint256 _vaultType) internal pure returns (bool) {
        return _vaultType == T1_VAULT_TYPE;
    }

    function isT2Vault(uint256 _vaultType) internal pure returns (bool) {
        return _vaultType == T2_VAULT_TYPE;
    }

    function isT3Vault(uint256 _vaultType) internal pure returns (bool) {
        return _vaultType == T3_VAULT_TYPE;
    }

    function isT4Vault(uint256 _vaultType) internal pure returns (bool) {
        return _vaultType == T4_VAULT_TYPE;
    }
}