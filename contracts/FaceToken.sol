pragma solidity ^0.4.24;

import "./StandardToken.sol";
import "./Owned.sol";

contract FaceToken is StandardToken, Owned {

  // Token metadata
  string public constant name = "FaceWorths Token";
  string public constant symbol = "FACE";
  uint256 public constant decimals = 6;
  address public constant initialVault = 0x412DC62C14EE8A473EF42AD8C494DC2E83A99FA1B6;

  constructor() public {
    totalSupply_ = (10**8) * 10**decimals; // 100 million
    balances[initialVault] = totalSupply_;
    emit Mint(initialVault, balances[initialVault]);
  }

  event Mint(address indexed to, uint256 amount);
}
