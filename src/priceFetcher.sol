// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVault} from "@balancer/vault/IVault.sol";
import {IManagedPool} from "@balancer/pool-utils/IManagedPool.sol";
import {IERC20} from "@balancer/solidity-utils/openzeppelin/IERC20.sol";
import {IUniswapV2Factory} from "@uniswap-v2/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap-v2/interfaces/IUniswapV2Pair.sol";

contract PriceFetcher {
    IVault vault;
    IManagedPool poolContr;
    address uniswapv2FactoryAddr;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function getPairPrice(
        address tokenA,
        address tokenB,
        uint256 poolId
    ) public returns (uint256) {
        uint256[] memory prices;

        uint256 uniswapPrice = getUniswapPrice(tokenA, tokenB);
        uint256 balancerPrice = getBalancerPrice(tokenA, tokenB, poolId);

        prices[0] = uniswapPrice;
        prices[1] = balancerPrice;

        return getAggregatedPrice(prices);
    }

    function getAggregatedPrice(
        uint256[] memory prices
    ) internal pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            sum += prices[i];
        }

        return sum / prices.length;
    }

    function getUniswapPrice(
        address tokenA,
        address tokenB
    ) internal view returns (uint256) {
        IUniswapV2Factory uniswapv2Factory = IUniswapV2Factory(
            uniswapv2FactoryAddr
        );
        address pairAddr = uniswapv2Factory.getPair(tokenA, tokenB);
        IUniswapV2Pair uniswapV2pair = IUniswapV2Pair(pairAddr);

        address token0 = uniswapV2pair.token0();
        //address token1 = uniswapV2pair.token1();

        (uint256 reserve0, uint256 reserve1, ) = uniswapV2pair.getReserves();
        uint256 balanceA;
        uint256 balanceB;

        if (tokenA == token0) {
            balanceA = reserve0;
            balanceB = reserve1;
        } else {
            balanceA = reserve1;
            balanceB = reserve0;
        }

        uint256 price = (balanceB * 1e18) / balanceA;
        return price;
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
