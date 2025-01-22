// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC20 {
    error Unauthorized();

    address private immutable i_manager;
    address private immutable i_token;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _token
    ) ERC20(_name, _symbol) {
        i_manager = _manager;
        i_token = _token;
    }

    modifier _onlyManager() {
        if (msg.sender != i_manager) revert Unauthorized();
        _;
    }

    function mint(address to, uint256 amount) external _onlyManager {
        _mint(to, amount);
    }

    function withdraw(
        address user,
        uint256 amount,
        uint256 burnAmount
    ) external _onlyManager {
        _burn(user, burnAmount);
        ERC20(i_token).transferFrom(address(this), i_manager, amount);
    }
}
