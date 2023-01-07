// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../ERC20.sol";

contract MockERC20 is TokenContract {
    constructor(string memory name, string memory symbol)
        TokenContract(1000000000e18, name, symbol)
    {}
}
