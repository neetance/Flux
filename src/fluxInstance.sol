// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FluxInstance {
    enum OptionType {
        CALL,
        PUT
    }

    uint256 public immutable i_strikePrice;
    uint256 public immutable i_expiry;

    address public s_owner;
    address public s_underlyingToken;
    address public s_settlementToken;

    OptionType public optionType;

    constructor(
        address _owner,
        OptionType _optionType,
        uint256 _strikePrice,
        uint256 _duration,
        address _underlyingToken,
        address _settlementToken
    ) {
        optionType = _optionType;
        i_strikePrice = _strikePrice;
        i_expiry = block.timestamp + _duration;
        s_owner = _owner;
        s_underlyingToken = _underlyingToken;
        s_settlementToken = _settlementToken;
    }
}
