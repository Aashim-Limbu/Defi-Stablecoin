// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;
import {ERC20Burnable,ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title  Decentralized Stable Coin
 * @author  Aashim Limbu
 *  Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This contract is meant to be governed by DCEngine. This contract is just the ERC20 implementation of the Decentralized Stable Coin.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__NoBalance();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();
    error DecentralizedStableCoin__MoreThanZero();
    constructor(address initialOwner) ERC20("Decentralized Stable Coin", "DSC") Ownable(initialOwner) { }
    function burn (uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if( _amount <=0 ){
            revert DecentralizedStableCoin__NoBalance();
        }
        if (_amount > balance){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
    function mint (address _to, uint256 _amount) external onlyOwner returns (bool){
        if(_to == address(0)){
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if(_amount <= 0 ){
            revert DecentralizedStableCoin__MoreThanZero();
        }
        _mint(_to,_amount);
        return true;
    }
}
