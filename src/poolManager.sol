// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Pool} from "./pool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";

contract PoolManager is CCIPReceiver {
    error Pool_Exists();
    error Pool_Does_Not_Exist();
    error Amount_Exceeds_Balance();

    event PoolCreated(address indexed token, address pool);
    event LiquidityDeposited(
        address indexed token,
        address indexed user,
        uint256 amount
    );
    event LiquidityWithdrawn(
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

        Pool pool = new Pool(name, symbol, address(this), token);
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
            payInLzToken: false
        });
        i_layerZero.send(messagingParams, address(this));
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (, address user) = abi.decode(any2EvmMessage.data, (uint256, address));
        uint256 amount = any2EvmMessage.destTokenAmounts[0].amount;
        address token = any2EvmMessage.destTokenAmounts[0].token;

        ERC20(token).transferFrom(address(this), pools[token], amount);
        Pool(pools[token]).mint(user, amount);

        emit LiquidityDeposited(token, user, amount);
    }

    function withdrawLiquidty(
        address _token,
        uint256 _amount,
        uint32 _chainId
    ) public {
        Pool pool = Pool(pools[_token]);
        uint256 userBalance = pool.balanceOf(msg.sender);
        if (userBalance < _amount) revert Amount_Exceeds_Balance();

        uint256 amountToTransfer = getTotalLiquidity(_token) /
            pool.totalSupply();
        pool.withdraw(msg.sender, amountToTransfer, _amount);

        MessagingParams memory messagingParams = MessagingParams({
            dstEid: _chainId,
            receiver: "",
            message: abi.encode(address(this), _token, msg.sender, _amount, ""),
            options: "",
            payInLzToken: false
        });
        i_layerZero.send(messagingParams, address(this));

        emit LiquidityWithdrawn(_token, msg.sender, _amount);
    }

    function getTotalLiquidity(address token) public view returns (uint256) {
        return ERC20(token).balanceOf(pools[token]);
    }
}
