pragma solidity ^0.4.24;


/**
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
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

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
  {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    c = a / b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b)
  internal
  pure
  returns (uint256 c)
  {
    assert(b <= a);
    c = a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b)
  internal
  pure
  returns (uint256 c)
  {
    c = a + b;
    assert(c >= a);
  }

}