pragma solidity ^0.4.24;

import "./StandardToken.sol";
import "./Owned.sol";

contract FaceToken is StandardToken, Owned {

  // Token metadata
  string public constant name = "FaceWorths Token";
  string public constant symbol = "FACE";
  uint256 public constant decimals = 6;
  address public vault;

  constructor(address _vault) public {
    vault = _vault;
    totalSupply_ = (10**8) * 10**decimals; // 100 million
    balances[vault] = totalSupply_;
    emit Mint(vault, balances[vault]);
  }

  event Mint(address indexed to, uint256 amount);
}
