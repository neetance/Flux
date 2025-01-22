// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Factory} from "./factory.sol";
import {PriceFetcher} from "./priceFetcher.sol";
import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";

contract FluxInstance {
    error Unauthorized();
    error Expired();
    error Already_Exercised();

    event OptionExercised(
        address indexed optionAddress,
        address indexed owner,
        address indexed underlyingToken,
        address settlementToken,
        uint256 amount
    );

    enum OptionType {
        CALL,
        PUT
    }

    uint256 public immutable i_strikePrice;
    uint256 public immutable i_expiry;
    uint256 public immutable i_balancerPoolId;
    uint256 public immutable i_amount;

    address public immutable i_owner;
    address public immutable i_underlyingToken;
    address public immutable i_settlementToken;

    bool public s_exercised;

    OptionType public immutable i_optionType;
    PriceFetcher private immutable i_priceFetcher;
    ILayerZeroEndpointV2 private immutable i_layerZero;
    Factory private immutable i_factory;

    constructor(
        address _owner,
        OptionType _optionType,
        uint256 _strikePrice,
        uint256 _amount,
        uint256 _expiration,
        uint256 _balancerPoolId,
        address _underlyingToken,
        address _settlementToken,
        address _priceFetcher,
        address _layerZero,
        address _factoryAddr
    ) {
        i_optionType = _optionType;
        i_strikePrice = _strikePrice;
        i_expiry = _expiration;
        i_owner = _owner;
        i_underlyingToken = _underlyingToken;
        i_settlementToken = _settlementToken;
        i_amount = _amount;
        i_priceFetcher = PriceFetcher(_priceFetcher);
        i_balancerPoolId = _balancerPoolId;
        s_exercised = false;
        i_layerZero = ILayerZeroEndpointV2(_layerZero);
        i_factory = Factory(_factoryAddr);
    }

    function exercise(uint32 _chainId) public {
        if (msg.sender != i_owner) revert Unauthorized();
        if (block.timestamp > i_expiry) revert Expired();
        if (s_exercised) revert Already_Exercised();

        s_exercised = true;
        uint256 amountToTransfer = i_amount * i_strikePrice;

        if (i_optionType == OptionType.CALL) {
            MessagingParams memory messagingParams = MessagingParams({
                dstEid: _chainId,
                receiver: "",
                message: abi.encode(
                    address(i_factory.getPool(i_settlementToken)),
                    i_settlementToken,
                    i_owner,
                    amountToTransfer,
                    ""
                ),
                options: "",
                payInLzToken: true
            });
            i_layerZero.send(messagingParams, address(this));
        } else {
            MessagingParams memory messagingParams = MessagingParams({
                dstEid: _chainId,
                receiver: "",
                message: abi.encode(
                    i_owner,
                    i_settlementToken,
                    address(i_factory.getPool(i_underlyingToken)),
                    i_amount,
                    ""
                ),
                options: "",
                payInLzToken: true
            });
            i_layerZero.send(messagingParams, address(this));
        }

        emit OptionExercised(
            address(this),
            i_owner,
            i_underlyingToken,
            i_settlementToken,
            amountToTransfer
        );
    }

    function getCurrentPrice() public returns (uint256) {
        return
            i_priceFetcher.getPairPrice(
                i_underlyingToken,
                i_settlementToken,
                i_balancerPoolId
            );
    }
}
