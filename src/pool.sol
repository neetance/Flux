// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    error Unauthorized();

    address private immutable i_manager;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager
    ) ERC20(_name, _symbol) {
        i_manager = _manager;
    }

    function mint(address to, uint256 amount) public {
        if (msg.sender != i_manager) revert Unauthorized();
        _mint(to, amount);
    }
}
