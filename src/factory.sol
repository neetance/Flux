// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FluxInstance} from "./fluxInstance.sol";

contract Factory {
    function createOption(
        FluxInstance.OptionType optionType,
        address underlyingToken,
        address settlementToken,
        uint256 strikePrice,
        uint256 duration
    ) public returns (address) {
        FluxInstance instance = new FluxInstance(
            msg.sender,
            optionType,
            strikePrice,
            duration,
            underlyingToken,
            settlementToken
        );

        return address(instance);
    }
}
