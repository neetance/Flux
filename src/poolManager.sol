// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {Pool} from "./pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";

contract PoolManager is CCIPReceiver {
    error Pool_Exists();
    error Pool_Does_Not_Exist();

    event PoolCreated(address indexed token, address pool);
    event LiquidityDeposited(
        address indexed token,
        address indexed user,
        uint256 amount
    );

    address private immutable i_factory;
    ILayerZeroEndpointV2 private immutable i_layerZero;

    mapping(address token => address pool) pools;

    constructor(
        address _factory,
        address _layerZero,
        address _router
    ) CCIPReceiver(_router) {
        i_factory = _factory;
        i_layerZero = ILayerZeroEndpointV2(_layerZero);
    }

    function createPool(address token) public returns (address) {
        if (pools[token] != address(0)) revert Pool_Exists();

        ERC20 tokenContract = ERC20(token);
        string memory name = string(
            abi.encodePacked("F", tokenContract.name())
        );
        string memory symbol = string(
            abi.encodePacked("F", tokenContract.symbol())
        );

        Pool pool = new Pool(name, symbol, address(this));
        pools[token] = address(pool);

        emit PoolCreated(token, address(pool));
        return address(pool);
    }

    function depositLiquidity(
        address _tokenAddr,
        uint256 _amount,
        uint32 _chainId
    ) public {
        if (pools[_tokenAddr] == address(0)) revert Pool_Does_Not_Exist();

        MessagingParams memory messagingParams = MessagingParams({
            dstEid: _chainId,
            receiver: "",
            message: abi.encode(
                msg.sender,
                _tokenAddr,
                address(this),
                _amount,
                ""
            ),
            options: "",
            payInLzToken: true
        });
        i_layerZero.send(messagingParams, address(this));
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (, address user) = abi.decode(any2EvmMessage.data, (uint256, address));
        uint256 amount = any2EvmMessage.destTokenAmounts[0].amount;
        address token = any2EvmMessage.destTokenAmounts[0].token;

        ERC20(token).transferFrom(user, pools[token], amount);
        Pool(pools[token]).mint(user, amount);

        emit LiquidityDeposited(token, user, amount);
    }

    function withdrawLiquidty(address token, uint256 amount) public {
        // Implementaiton pending
    }
}
