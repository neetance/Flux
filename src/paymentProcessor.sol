// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract PaymentProcessor {
    error Unauthorized();
    error Transfer_Failed();

    address factory;
    address poolManager;
    uint32 destId;
    ILayerZeroEndpointV2 layerZeroEndpoint;

    constructor(
        address _factory,
        address _pool,
        address _layerZeroEndpointAddr,
        uint32 _destId
    ) {
        factory = _factory;
        poolManager = _pool;
        layerZeroEndpoint = ILayerZeroEndpointV2(_layerZeroEndpointAddr);
        destId = _destId;
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        if (msg.sender != address(layerZeroEndpoint)) revert Unauthorized();

        (address user, address token, uint256 value) = abi.decode(
            _message,
            (address, address, uint256)
        );
        bool success = IERC20(token).transferFrom(user, address(this), value);
        if (!success) revert Transfer_Failed();

        //  MessagingParams memory messageParams = MessagingParams({
        //     dstEid: destId,
        //     receiver:
        //  }
        //  );
    }
}
