// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public antiparallelTokenAddress;

    // Exchange inheriting ERC20 in order to keep track of LP tokens
    constructor(address _AntiparallelToken) ERC20("Antiparallel LP Token", "APLP") {
        require(_AntiparallelToken != address(0), "Token address passed is a null address");
        antiparallelTokenAddress = _AntiparallelToken;
    }
}