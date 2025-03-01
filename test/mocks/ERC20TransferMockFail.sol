// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20TransferMockFails is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(address owner) ERC20("DecentralizedStableCoin", "DSC") Ownable(owner) {}

    function burn(uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(balance == 0) revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        if(balance < _amount) revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        super.burn(_amount);
    }
    function mint(address account,uint256 amountToMint) public onlyOwner{
        _mint(account,amountToMint);
    }
    function transfer(address /*recipent address*/,uint256 /*amount to Transfer*/) public override pure returns(bool) {
        return false;
    }
}
