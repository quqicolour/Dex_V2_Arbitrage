// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 0x02E1A80D80c3F1DE3492C14ce391ba94823E39F8
contract TestMatic is ERC20 {
    constructor() ERC20("Test Matic", "TMATIC") {
        _mint(msg.sender,10000000000000000000 * 1 ether);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}