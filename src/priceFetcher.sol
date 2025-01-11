// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IVault} from "@balancer/vault/IVault.sol";
import {IManagedPool} from "@balancer/pool-utils/IManagedPool.sol";
import {IERC20} from "@balancer/solidity-utils/openzeppelin/IERC20.sol";

contract PriceFetcher {
    IVault vault;
    IManagedPool poolContr;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function getBalancerPrice(
        address tokenA,
        address tokenB,
        uint256 poolId
    ) internal returns (uint256) {
        uint256[] memory balances;
        IERC20[] memory tokens;

        (tokens, balances, ) = vault.getPoolTokens(bytes32(poolId));
        uint256 balanceA;
        uint256 balanceB;

        address pool;
        (pool, ) = vault.getPool(bytes32(poolId));

        poolContr = IManagedPool(pool);
        uint256[] memory weights;
        weights = poolContr.getNormalizedWeights();

        uint256 weightA;
        uint256 weightB;

        for (uint256 i = 0; i < tokens.length; i++) {
            if (address(tokens[i]) == tokenA) {
                balanceA = balances[i];
                weightA = weights[i];
            }

            if (address(tokens[i]) == tokenB) {
                balanceB = balances[i];
                weightB = weights[i];
            }
        }

        uint256 price = (balanceB * weightB) / (balanceA * weightA);
        return price;
    }
}
