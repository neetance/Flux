// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FluxInstance} from "./fluxInstance.sol";
import {PremiumCalculator} from "./premiumCalculator.sol";
import {PriceFetcher} from "./priceFetcher.sol";

contract Factory {
    error Only_Owner_Can_Call();
    error Not_Enough_Premium();

    event OptionCreated(
        address indexed optionAddress,
        address indexed owner,
        FluxInstance.OptionType optionType,
        address underlyingToken,
        address settlementToken,
        uint256 strikePrice,
        uint256 duration,
        uint256 premium
    );

    uint256 public s_optionId;
    PremiumCalculator private immutable i_premiumCalculator;
    PriceFetcher private immutable i_priceFetcher;

    mapping(address instance => address owner) public s_owners;
    mapping(uint256 id => OptionParams params) public s_options;

    struct OptionParams {
        FluxInstance.OptionType optionType;
        address owner;
        address underlyingToken;
        address settlementToken;
        uint256 strikePrice;
        uint256 expirationDate;
        uint256 id;
        uint256 premium;
    }

    constructor(address _premiumCalculator, address _priceFetcher) {
        i_premiumCalculator = PremiumCalculator(_premiumCalculator);
        i_priceFetcher = PriceFetcher(_priceFetcher);
        s_optionId = 0;
    }

    function proposeOption(
        FluxInstance.OptionType _optionType,
        address _underlyingToken,
        address _settlementToken,
        uint256 _strikePrice,
        uint256 _duration
    ) public returns (uint256 id, uint256 premium) {
        id = s_optionId;
        s_optionId += 1;

        uint256 currentPrice = i_priceFetcher.getPairPrice(
            _underlyingToken,
            _settlementToken,
            id
        );

        i_premiumCalculator.requestGetPremium(
            _underlyingToken,
            currentPrice,
            _strikePrice,
            block.timestamp + _duration,
            _optionType,
            id
        );

        premium = i_premiumCalculator.getPremium(id);
        OptionParams memory params = OptionParams({
            optionType: _optionType,
            owner: msg.sender,
            underlyingToken: _underlyingToken,
            settlementToken: _settlementToken,
            strikePrice: _strikePrice,
            expirationDate: block.timestamp + _duration,
            id: id,
            premium: premium
        });
        s_options[id] = params;
    }

    function createOption(uint256 id) public payable returns (address) {
        OptionParams memory params = s_options[id];
        if (msg.sender != params.owner) {
            revert Only_Owner_Can_Call();
        }

        uint256 premium = params.premium;
        if (msg.value < premium) {
            revert Not_Enough_Premium();
        }

        FluxInstance instance = new FluxInstance(
            params.owner,
            params.optionType,
            params.strikePrice,
            params.expirationDate,
            params.underlyingToken,
            params.settlementToken
        );
        emit OptionCreated(
            address(instance),
            params.owner,
            params.optionType,
            params.underlyingToken,
            params.settlementToken,
            params.strikePrice,
            params.expirationDate,
            premium
        );

        return address(instance);
    }
}
