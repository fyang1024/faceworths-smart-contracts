pragma solidity ^0.4.24;

contract FaceWorthPoll {

  uint constant STAKE = 100000000; // every participant stake 100 trx
  uint constant MIN_PARTICIPANTS = 10;
  uint constant MAX_PARTICIPANTS = 500;
  uint constant WINNERS_RETURN = 3;
  uint constant RETAINED_PERCENTAGE = 10;

  address public owner; // owner should be FaceWorthPollFactory contract
  address public initiator; // initiator is the one who wants to get his/her own FaceWorth
  bytes32 public faceHash; // face photo's SHA-256 hash
  uint public startingBlock;
  uint public endingBlock;
  bool public open;
  bool public prizeDistributed;

  mapping(address=>uint8) private worthBook;
  mapping(address=>bool) private evaluatedBook;
  mapping(address=>uint) private diffBook;
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
    if (participantsRequired < MIN_PARTICIPANTS || participantsRequired > MAX_PARTICIPANTS) {
      open = false;
    } else {
      open = true;
    }
    prizeDistributed = false;
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
    require (!evaluatedBook[msg.sender]);
    _;
  }

  modifier prizeNotDistributed {
    require (!prizeDistributed);
    _;
  }

  function evaluate(uint8 _worth) payable external whenOpen onlyOnce {
    require(_worth >= 0 && _worth <=100);
    require(msg.value == STAKE);
    participantsCount++;
    worthBook[msg.sender] = _worth;
    evaluatedBook[msg.sender] = true;
    participants.push(msg.sender);
    if (participantsCount >= participantsRequired) {
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
    open = false;
    buildDiffBook();

    uint numOfWinners = participantsCount / WINNERS_RETURN;
    uint[] memory winnersDiff;
    address[] memory winners;
    uint count = 0;
    for(uint i = 0; i < participants.length; i++) {
      if (count < numOfWinners) {
        winners[count] = participants[i];
        winnersDiff[count] = diffBook[participants[i]];
        count++;
      } else {
        for (uint j = 0; j < numOfWinners; j++) {
          if (winnersDiff[j] > diffBook[participants[i]]) {
            winners[j] = participants[i];
            winnersDiff[j] = diffBook[participants[i]];
            break;
          }
        }
      }
    }

    //TODO how to distribute prize?
    uint totalWinnersDiff = getTotal(winnersDiff);
    uint avgDiff = totalWinnersDiff / numOfWinners;
    uint totalPrize = STAKE * participantsCount * (100 - RETAINED_PERCENTAGE) / 100;
    uint avgPrize = totalPrize / numOfWinners;
    for (uint k = 0; k < numOfWinners; k++) {

    }
  }

  function getTotal(uint[] a) private pure returns (uint total_) {
    uint total = 0;
    for (uint i = 0; i < a.length; i++) {
      total += a[i];
    }
    return total;
  }

  function buildDiffBook() private {
    uint totalWorth = getTotalWorth();
    for(uint i = 0; i < participants.length; i++) {
      uint adjustedWorth = worthBook[participants[i]] * participants.length;
      if (adjustedWorth > totalWorth) {
        diffBook[participants[i]] = adjustedWorth - totalWorth;
      } else {
        diffBook[participants[i]] = totalWorth - adjustedWorth;
      }
    }
  }

  function getTotalWorth() private view returns (uint totalWorth_) {
    uint total = 0;
    for(uint i = 0; i < participants.length; i++) {
      total += worthBook[participants[i]];
    }
    return total;
  }

  function refund() private {
    for (uint i = 0; i < participants.length; i++) {
      participants[i].transfer(STAKE);
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