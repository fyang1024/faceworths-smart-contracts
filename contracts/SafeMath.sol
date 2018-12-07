pragma solidity ^0.4.24;


library SafeMath {

  function mul(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    // @dev this is cheaper than asserting 'a' not being zero, but the benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      c = 0;
    }

    c = a * b;
    assert(c / a == b);
  }

  function sub(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    assert(b <= a);
    c = a - b;
  }

  function add(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    c = a + b;
    assert(c >= a);
  }

}