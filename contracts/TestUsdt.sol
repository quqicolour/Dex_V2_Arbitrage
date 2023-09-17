// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 0x2F6Ec96e6c64a910f5199CDF7Ad9a8456b254f99
contract TestUsdt is ERC20 {
    constructor() ERC20("Test Usdt", "TUSDT") {
        _mint(msg.sender,10000000000000000000 * 1 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}