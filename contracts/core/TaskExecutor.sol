// SPDX-License-Identifier: MIT

pragma solidity =0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/ILendingPool.sol";
import "../auth/ProxyPermission.sol";
import "../actions/ActionBase.sol";
import "../core/DFSRegistry.sol";
import "./Subscriptions.sol";

/// @title Handles FL taking and executes actions
contract TaskExecutor is StrategyData, ProxyPermission, AdminAuth {
    address public constant DEFISAVER_LOGGER = 0x5c55B921f590a89C1Ebe84dF170E655a82b62126;

    address public constant REGISTRY_ADDR = 0xE8D0F37C03cD58A431dC903C9ff262523F751EE7;
    DFSRegistry public constant registry = DFSRegistry(REGISTRY_ADDR);

    bytes32 constant ACTION_EXECUTOR_ID = keccak256("ActionExecutor");
    bytes32 constant SUBSCRIPTION_ID = keccak256("Subscriptions");

    /// @notice Called directly through DsProxy to execute a task
    /// @dev This is the main entry point for Recipes/Tasks executed manually
    /// @param _currTask Task to be executed
    function executeTask(Task memory _currTask) public payable   {
        _executeActions(_currTask);
    }

    /// @notice Called through the Strategy contract to execute a task
    /// @param _strategyId Id of the strategy we want to execute
    /// @param _actionCallData All the data related to the strategies Task
    function executeStrategyTask(uint256 _strategyId, bytes[][] memory _actionCallData)
        public
        payable
    {
        address subAddr = registry.getAddr(SUBSCRIPTION_ID);
        Strategy memory strategy = Subscriptions(subAddr).getStrategy(_strategyId);
        Template memory template = Subscriptions(subAddr).getTemplate(strategy.templateId);

        Task memory currTask =
            Task({
                name: template.name,
                callData: _actionCallData,
                subData: strategy.subData,
                actionIds: template.actionIds,
                paramMapping: template.paramMapping
            });

        _executeActions(currTask);
    }

    /// @notice This is the callback function that FL actions call
    /// @dev FL function must be the first action and repayment is done last
    /// @param _currTask Task to be executed
    /// @param _flAmount Result value from FL action
    function _executeActionsFromFL(Task memory _currTask, bytes32 _flAmount) public payable {
        bytes32[] memory returnValues = new bytes32[](_currTask.actionIds.length);
        returnValues[0] = _flAmount; // set the flash loan action as first return value

        // skips the first actions as it was the fl action
        for (uint256 i = 1; i < _currTask.actionIds.length; ++i) {
            returnValues[i] = _executeAction(_currTask, i, returnValues);
        }
    }

    /// @notice Runs all actions from the task
    /// @dev FL action must be first and is parsed separately, execution will go to _executeActionsFromFL
    /// @param _currTask to be executed
    function _executeActions(Task memory _currTask) internal {
        address firstActionAddr = registry.getAddr(_currTask.actionIds[0]);

        bytes32[] memory returnValues = new bytes32[](_currTask.actionIds.length);

        if (isFL(firstActionAddr)) {
            _parseFLAndExecute(_currTask, firstActionAddr, returnValues);
        } else {
            for (uint256 i = 0; i < _currTask.actionIds.length; ++i) {
                returnValues[i] = _executeAction(_currTask, i, returnValues);
            }
        }

        /// log the task name
        DefisaverLogger(DEFISAVER_LOGGER).Log(address(this), msg.sender, _currTask.name, "");
    }

    /// @notice Gets the action address and executes it
    /// @param _currTask Task to be executed
    /// @param _index Index of the action in the task array
    /// @param _returnValues Return values from previous actions
    function _executeAction(
        Task memory _currTask,
        uint256 _index,
        bytes32[] memory _returnValues
    ) internal returns (bytes32 response) {
        response = IDSProxy(address(this)).execute(
            registry.getAddr(_currTask.actionIds[_index]),
            abi.encodeWithSignature(
                "executeAction(bytes[],bytes[],uint8[],bytes32[])",
                _currTask.callData[_index],
                _currTask.subData[_index],
                _currTask.paramMapping[_index],
                _returnValues
            )
        );
    }

    /// @notice Prepares and executes a flash loan action
    /// @dev It adds to the last input value of the FL, the task data so it can be passed on
    /// @param _currTask Task to be executed
    /// @param _flActionAddr Address of the flash loan action
    /// @param _returnValues An empty array of return values, because it's the first action
    function _parseFLAndExecute(
        Task memory _currTask,
        address _flActionAddr,
        bytes32[] memory _returnValues
    ) internal {
        givePermission(_flActionAddr);

        bytes memory taskData = abi.encode(_currTask, address(this));

        // last input value is empty for FL action, attach task data there
        _currTask.callData[0][_currTask.callData[0].length - 1] = taskData;

        /// @dev FL action is called directly so that we can check who the msg.sender of FL is
        ActionBase(_flActionAddr).executeAction(
            _currTask.callData[0],
            _currTask.subData[0],
            _currTask.paramMapping[0],
            _returnValues
        );

        removePermission(_flActionAddr);
    }

    /// @notice Checks if the specified address is of FL type action
    /// @param _actionAddr Address of the action
    function isFL(address _actionAddr) internal pure returns (bool) {
        return ActionBase(_actionAddr).actionType() == uint8(ActionBase.ActionType.FL_ACTION);
    }
}
