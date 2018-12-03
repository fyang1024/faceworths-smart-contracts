pragma solidity ^0.4.23;

import "./StandardToken.sol";
import "./Owned.sol";

contract FaceToken is StandardToken, Owned {

  // Token metadata
  string public constant name = "FaceWorths Token";
  string public constant symbol = "FACE";
  uint256 public constant decimals = 6;
  address public constant initialVault = 0x2dc62c14ee8a473Ef42Ad8c494dC2E83a99fa1b6;

  constructor() public {
    totalSupply_ = (10**8) * 10**decimals; // 100 million
    balances[initialVault] = totalSupply_;
    emit Mint(initialVault, balances[initialVault]);
  }

  event Mint(address indexed to, uint256 amount);
}
