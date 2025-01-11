// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FluxInstance} from "./fluxInstance.sol";

contract Factory {
    event OptionCreated(
        address indexed optionAddress,
        address indexed owner,
        FluxInstance.OptionType optionType,
        address underlyingToken,
        address settlementToken,
        uint256 strikePrice,
        uint256 duration
    );

    mapping(address instance => address owner) public owners;

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

        emit OptionCreated(
            address(instance),
            msg.sender,
            optionType,
            underlyingToken,
            settlementToken,
            strikePrice,
            duration
        );

        owners[address(instance)] = msg.sender;
        return address(instance);
    }
}
