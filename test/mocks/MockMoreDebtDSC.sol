// SPDX-License-Identifier: MTI
pragma solidity >= 0.8.0 < 0.9.0;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockV3Aggregator} from "@chainlink/contracts/v0.8/tests/MockV3Aggregator.sol";

contract MockMoreDebtDSC is ERC20Burnable, Ownable {
    address mockAggregator;

    error DecentralizedStableCoin__AmountMustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(address owner, address _mockAggregator) ERC20("DecentralizedStableCoin", "DSC") Ownable(owner) {
        mockAggregator = _mockAggregator;
    }

    function burn(uint256 _amount) public override onlyOwner {
        MockV3Aggregator(mockAggregator).updateAnswer(0);
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
    function mint (address _to,uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if(_amount <= 0 ){
            revert DecentralizedStableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to,_amount);
        return true;
    }
}
