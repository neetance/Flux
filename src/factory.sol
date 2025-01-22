// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FluxInstance} from "./fluxInstance.sol";
import {PremiumCalculator} from "./premiumCalculator.sol";
import {PriceFetcher} from "./priceFetcher.sol";
import {CCIPReceiver} from "@chainlink-ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink-ccip/libraries/Client.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@layerzero-v2/interfaces/ILayerZeroEndpointV2.sol";

contract Factory is CCIPReceiver {
    error Only_Owner_Can_Call();
    error Premium_Not_Paid();

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
    event PremiumReceived(uint256 indexed optionId);

    uint256 public s_optionId;
    PremiumCalculator private immutable i_premiumCalculator;
    PriceFetcher private immutable i_priceFetcher;
    ILayerZeroEndpointV2 private immutable i_layerZero;

    mapping(address instance => address owner) public s_owners;
    mapping(uint256 id => OptionParams params) public s_options;
    mapping(uint32 chainId => address paymentProcessorAddr) paymentProcessorAddrs;
    mapping(address token => address pool) pools;

    struct OptionParams {
        FluxInstance.OptionType optionType;
        address owner;
        address underlyingToken;
        address settlementToken;
        uint256 strikePrice;
        uint256 amount;
        uint256 expirationDate;
        uint256 id;
        uint256 premium;
        bool premiumPaid;
    }

    constructor(
        address _premiumCalculator,
        address _priceFetcher,
        address _layerZero,
        address _router
    ) CCIPReceiver(_router) {
        i_premiumCalculator = PremiumCalculator(_premiumCalculator);
        i_priceFetcher = PriceFetcher(_priceFetcher);
        s_optionId = 0;
        i_layerZero = ILayerZeroEndpointV2(_layerZero);
    }

    function proposeOption(
        FluxInstance.OptionType _optionType,
        address _underlyingToken,
        address _settlementToken,
        uint256 _strikePrice,
        uint256 _amount,
        uint256 _duration,
        uint32 _chainId,
        uint256 _balancerPoolId
    ) public returns (uint256 id, uint256 premium) {
        id = s_optionId;
        s_optionId += 1;

        uint256 currentPrice = i_priceFetcher.getPairPrice(
            _underlyingToken,
            _settlementToken,
            _balancerPoolId
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
            amount: _amount,
            expirationDate: block.timestamp + _duration,
            id: id,
            premium: premium,
            premiumPaid: false
        });
        s_options[id] = params;

        MessagingParams memory messagingParams = MessagingParams({
            dstEid: _chainId,
            receiver: "",
            message: abi.encode(
                msg.sender,
                _underlyingToken,
                address(this),
                premium * _amount,
                id
            ),
            options: "",
            payInLzToken: true
        });
        i_layerZero.send(messagingParams, address(this));
    }

    function createOption(
        uint256 id,
        uint256 _balancerPoolId
    ) public payable returns (address) {
        OptionParams memory params = s_options[id];
        if (msg.sender != params.owner) {
            revert Only_Owner_Can_Call();
        }

        if (!params.premiumPaid) revert Premium_Not_Paid();

        FluxInstance instance = new FluxInstance(
            params.owner,
            params.optionType,
            params.strikePrice,
            params.amount,
            params.expirationDate,
            _balancerPoolId,
            params.underlyingToken,
            params.settlementToken,
            address(i_priceFetcher),
            address(i_layerZero),
            address(this)
        );
        emit OptionCreated(
            address(instance),
            params.owner,
            params.optionType,
            params.underlyingToken,
            params.settlementToken,
            params.strikePrice,
            params.expirationDate,
            params.premium
        );

        return address(instance);
    }

    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    ) internal override {
        (uint256 optionId, ) = abi.decode(
            any2EvmMessage.data,
            (uint256, address)
        );
        OptionParams storage params = s_options[optionId];
        address token = params.underlyingToken;
        address pool = pools[token];
        ERC20(token).transferFrom(address(this), pool, params.premium);

        params.premiumPaid = true;
        emit PremiumReceived(optionId);
    }

    function getPool(address token) public view returns (address) {
        return pools[token];
    }
}
