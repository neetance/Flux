// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink-ccip/interfaces/IRouterClient.sol";
import {IRouter} from "@chainlink-ccip/interfaces/IRouter.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";

contract PaymentProcessor {
    error Unauthorized();
    error Transfer_Failed();

    event TokensSent(
        uint256 indexed chainId,
        address indexed receiver,
        address token,
        uint256 amount
    );

    address factory;
    address poolManager;
    address ccip_router;
    uint32 destId;
    ILayerZeroEndpointV2 layerZeroEndpoint;

    constructor(
        address _factory,
        address _pool,
        address _ccip_router,
        address _layerZeroEndpointAddr,
        uint32 _destId
    ) {
        factory = _factory;
        poolManager = _pool;
        layerZeroEndpoint = ILayerZeroEndpointV2(_layerZeroEndpointAddr);
        destId = _destId;
        ccip_router = _ccip_router;
    }

    function lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) external payable {
        if (msg.sender != address(layerZeroEndpoint)) revert Unauthorized();

        (
            address user,
            address token,
            address recipient,
            uint256 value,
            uint256 optionId
        ) = abi.decode(_message, (address, address, address, uint256, uint256));
        bool success = IERC20(token).transferFrom(user, address(this), value);
        if (!success) revert Transfer_Failed();

        IRouter router = IRouter(ccip_router);
        Client.EVMTokenAmount[] memory tokens = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount = Client.EVMTokenAmount(
            token,
            value
        );

        tokens[0] = tokenAmount;
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(0),
            sourceChainSelector: uint64(block.chainid),
            sender: abi.encode(address(this)),
            data: abi.encode(optionId, user),
            destTokenAmounts: tokens
        });

        IERC20(token).approve(ccip_router, value);
        router.routeMessage(message, 0, 40000, recipient);

        emit TokensSent(destId, recipient, token, value);
    }
}
