// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

contract TestTime{

    function getThisTime()external view returns(uint){
        return block.timestamp;
    }
}