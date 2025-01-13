// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ChainlinkClient, Chainlink} from "@chainlink-contracts/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink-contracts/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink-contracts/shared/interfaces/LinkTokenInterface.sol";
import {FluxInstance} from "./fluxInstance.sol";

contract PremiumCalculator is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    event PremiumReceived(uint256 indexed optionId, uint256 premium);
    event PremiumRequestSent(
        bytes32 indexed requestId,
        uint256 indexed optionId
    );

    bytes32 private jobId;
    uint256 private fee;
    string private baseUrl;

    mapping(bytes32 requestId => uint256 optionId) private s_reqIdToOptionId;
    mapping(uint256 optionId => uint256 premium) private s_premiums;

    constructor() ConfirmedOwner(msg.sender) {
        _setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        _setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "53f9755920cd451a8fe46f5087468395";
        fee = (1 * LINK_DIVISIBILITY) / 10;
    }

    function requestGetPremium(
        uint256 currentPrice,
        uint256 strikePrice,
        uint256 expiryDate,
        FluxInstance.OptionType optionType,
        uint256 _optionId
    ) external {
        string memory url = string(
            abi.encodePacked(
                baseUrl,
                "?currentPrice=",
                currentPrice,
                "&strikePrice=",
                strikePrice,
                "&timeToExpiration=",
                expiryDate
            )
        );
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        req._add("url", url);
        if (optionType == FluxInstance.OptionType.CALL)
            req._add("pathCall", "callPremium");
        else req._add("pathPut", "putPremium");

        bytes32 reqId = _sendChainlinkRequest(req, fee);
        s_reqIdToOptionId[reqId] = _optionId;

        emit PremiumRequestSent(reqId, _optionId);
    }

    function getPremium(
        uint256 _optionId
    ) public view returns (uint256 premium) {
        premium = s_premiums[_optionId];
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function fulfill(
        bytes32 _requestId,
        uint256 _premium
    ) public recordChainlinkFulfillment(_requestId) {
        uint256 optionId = s_reqIdToOptionId[_requestId];
        s_premiums[optionId] = _premium;

        emit PremiumReceived(optionId, _premium);
    }
}
