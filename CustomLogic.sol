// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AutomationCompatibleInterface } from "@chainlink/contracts@1.3.0/src/v0.8/automation/AutomationCompatible.sol";

contract CustomLogic is AutomationCompatibleInterface {
    uint256 public counter;
    uint256 public immutable i_updateInterval;
    uint256 public lastTimeStamp;

    // this will help us set an interval for updates
    constructor(uint256 _updateInterval) {
        i_updateInterval = _updateInterval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata) external view override returns(bool upKeepNeeded,bytes memory performData){
        upKeepNeeded = (block.timestamp - lastTimeStamp) > i_updateInterval;
        performData = "";
    }

    function performUpkeep(bytes calldata) external  override {
        if((block.timestamp - lastTimeStamp) > i_updateInterval) {
            lastTimeStamp = block.timestamp;
            counter = counter + 1;
        }
    }
}