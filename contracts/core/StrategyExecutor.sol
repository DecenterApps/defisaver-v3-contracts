// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../auth/AdminAuth.sol";
import "../interfaces/ITrigger.sol";
import "../interfaces/IDSProxy.sol";
import "./StrategyData.sol";
import "./Subscriptions.sol";
import "./BotAuth.sol";
import "./DFSRegistry.sol";
import "./ProxyAuth.sol";

/// @title Main entry point for executing automated strategies
contract StrategyExecutor is StrategyData, AdminAuth {

    address public constant PROXY_AUTH_ADDR = 0xebA5415FF1ad2c072AA84085E2F4318f0E4B8695;

    address public constant REGISTRY_ADDR = 0xB0e1682D17A96E8551191c089673346dF7e1D467;
    DFSRegistry public constant registry = DFSRegistry(REGISTRY_ADDR);

    bytes32 constant BOT_AUTH_ID = keccak256("BotAuth");
    bytes32 constant SUBSCRIPTION_ID = keccak256("Subscriptions");
    bytes32 constant TASK_MANAGER_ID = keccak256("TaskExecutor");

    string public constant ERR_TRIGGER_NOT_ACTIVE = "Trigger not activated";
    string public constant ERR_BOT_NOT_APPROVED = "Bot is not approved";
    string public constant ERR_STRATEGY_NOT_ACTIVE = "Strategy is not active";

    /// @notice Checks all the triggers and executes actions
    /// @dev Only authorized callers can execute it
    /// @param _strategyId Id of the strategy
    /// @param _triggerCallData All input data needed to execute triggers
    /// @param _actionsCallData All input data needed to execute actions
    function executeStrategy(
        uint256 _strategyId,
        bytes[][] memory _triggerCallData,
        bytes[][] memory _actionsCallData
    ) public   {
        Subscriptions sub = Subscriptions(registry.getAddr(SUBSCRIPTION_ID));

        Strategy memory strategy = sub.getStrategy(_strategyId);
        require(strategy.active, ERR_STRATEGY_NOT_ACTIVE);

        // check bot auth
        checkCallerAuth(_strategyId);

        // check if all the triggers are true
        checkTriggers(_strategyId, strategy, _triggerCallData, sub);

        // execute actions
        callActions(_strategyId, strategy, _actionsCallData);
    }

    /// @notice Checks if msg.sender has auth, reverts if not
    /// @param _strategyId Id of the strategy
    function checkCallerAuth(uint256 _strategyId) public view {
        address botAuthAddr = registry.getAddr(BOT_AUTH_ID);
        require(
            BotAuth(botAuthAddr).isApproved(_strategyId, msg.sender),
            ERR_BOT_NOT_APPROVED
        );
    }

    /// @notice Checks if all the triggers are true, reverts if not
    /// @param _strategy Strategy data we have in storage
    /// @param _triggerCallData All input data needed to execute triggers
    function checkTriggers(
        uint _strategyId,
        Strategy memory _strategy,
        bytes[][] memory _triggerCallData,
        Subscriptions _sub
    ) public {

        bytes32[] memory triggerIds = _sub.getTemplateFromStrategy(_strategyId).triggerIds;

        for (uint256 i = 0; i < triggerIds.length; ++i) {
            address triggerAddr = registry.getAddr(triggerIds[i]);

            // TODO: change the 0
            bool isTriggered = ITrigger(triggerAddr).isTriggered(_triggerCallData[i][0], _strategy.triggerData[i][0]);
            require(isTriggered, ERR_TRIGGER_NOT_ACTIVE);
        }
    }

    /// @notice Execute all the actions in order
    /// @param _strategy Strategy data we have in storage
    /// @param _actionsCallData All input data needed to execute actions
    function callActions(uint _strategyId, Strategy memory _strategy, bytes[][] memory _actionsCallData) internal {
        address actionManagerProxyAddr = registry.getAddr(TASK_MANAGER_ID);

        ProxyAuth(PROXY_AUTH_ADDR).callExecute{value: msg.value}(
            _strategy.proxy,
            actionManagerProxyAddr,
            abi.encodeWithSignature(
                "executeStrategyTask(uint256,bytes[][])",
                _strategyId,
                _actionsCallData
            )
        );
    }
}
