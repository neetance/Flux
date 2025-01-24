// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Factory} from "../src/factory.sol";
import {PaymentProcessor} from "../src/paymentProcessor.sol";
import {PoolManager} from "../src/poolManager.sol";
import {PremiumCalculator} from "../src/premiumCalculator.sol";
import {PriceFetcher} from "../src/priceFetcher.sol";

contract DeployFlux is Script {
    Factory factory;
    PaymentProcessor paymentProcessor;
    PoolManager poolManager;
    PremiumCalculator premiumCalculator;
    PriceFetcher priceFetcher;

    address private vault; // value to be added
    address private layerZero; // value to be added
    address private router; // value to be added
    uint32 private destId; // value to be added

    function run()
        external
        returns (
            Factory,
            PaymentProcessor,
            PoolManager,
            PremiumCalculator,
            PriceFetcher
        )
    {
        vm.startBroadcast();
        premiumCalculator = new PremiumCalculator();
        priceFetcher = new PriceFetcher(vault);
        factory = new Factory(
            address(premiumCalculator),
            address(priceFetcher),
            layerZero,
            router
        );
        poolManager = new PoolManager(address(factory), layerZero, router);
        paymentProcessor = new PaymentProcessor(
            address(factory),
            address(poolManager),
            router,
            layerZero,
            destId
        );
        vm.stopBroadcast();

        return (
            factory,
            paymentProcessor,
            poolManager,
            premiumCalculator,
            priceFetcher
        );
    }
}
