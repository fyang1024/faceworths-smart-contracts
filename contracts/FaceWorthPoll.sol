pragma solidity ^0.4.24;

contract FaceWorthPoll {

  uint constant stake = 100000000; // every participant stake 100 trx
  address public owner; // owner should be FaceWorthPollFactory contract
  address public initiator; // initiator is the one who wants to get his/her own FaceWorth
  bytes32 public faceHash; // face photo's SHA-256 hash
  uint public startingBlock;
  uint public endingBlock;
  bool public open;
  mapping(address=>uint8) private worthBook;
  mapping(address=>bool) private evaluated;
  uint private participantsRequired;
  address[] private participants;
  uint private participantsCount;


  constructor(address _initiator, bytes32 _faceHash, uint _endingBlock, uint _participantsRequired) public {
    owner = msg.sender;
    initiator = _initiator;
    faceHash = _faceHash;
    startingBlock = block.number;
    endingBlock = _endingBlock;
    participantsRequired = _participantsRequired;
    participantsCount = 0;
    open = true;
  }

  modifier whenOpen {
    require (open);
    _;
  }

  modifier whenClosed {
    require (!open);
    _;
  }

  modifier onlyOwner {
    require (msg.sender == owner);
    _;
  }

  modifier onlyOnce {
    require (!evaluated[msg.sender]);
    _;
  }

  function evaluate(uint8 _worth) payable external whenOpen onlyOnce {
    require(_worth >= 0 && _worth <=100);
    require(msg.value == stake);
    participantsCount++;
    worthBook[msg.sender] = _worth;
    evaluated[msg.sender] = true;
    participants.push(msg.sender);
    if (participantsCount >= participantsRequired) {
      open = false;
      endPoll();
    } else {
      checkBlockNumber();
    }
  }

  function checkBlockNumber() public whenOpen {
    if (block.number >= endingBlock) {
      open = false;
      if (participantsCount < participantsRequired) {
        refund();
      }
    }
  }

  function endPoll() private {
    //TODO implement me
    uint totalWorth = getTotalWorth();
    for(uint i = 0; i < participants.length; i++) {

    }
  }

  function getTotalWorth() private view returns (uint totalWorth_) {
    uint sum = 0;
    for(uint i = 0; i < participants.length; i++) {
      sum += worthBook[participants[i]];
    }
    return sum;
  }

  function refund() private {
    for (uint i = 0; i < participants.length; i++) {
      participants[i].transfer(stake);
    }
  }

  function getParticipationProgress() external view returns (uint percentage_) {
    return participantsCount * 100 / participantsRequired;
  }

  function getTimePassed() external view returns (uint percentage_) {
    return (block.number - startingBlock) * 100 / (endingBlock - block.number);
  }

  function getParticipants() external view whenClosed returns (address[] participants_) {
    return participants;
  }

  function getWorth(address _who) external view whenClosed returns (uint8 worth_) {
    return worthBook[_who];
  }
}
