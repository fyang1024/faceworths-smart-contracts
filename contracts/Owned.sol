pragma solidity ^0.4.24;

contract Owned {

  event OwnershipTransferred(address indexed _from, address indexed _to);

  address public owner;
  address public newOwner;

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  constructor() public {
    owner = msg.sender;
  }

  function transferOwnership(address _newOwner) public onlyOwner {
    newOwner = _newOwner;
  }

  function acceptOwnership() public {
    require(msg.sender == newOwner);
    owner = newOwner;
    newOwner = address(0);
    emit OwnershipTransferred(owner, newOwner);
  }

}