// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

// import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../ERC20Permit.sol";

contract MockERC20Permit is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint8 _chainID
    ) ERC20(_name, _symbol, _decimals, chainID) {}

    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
