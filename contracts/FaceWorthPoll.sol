pragma solidity ^0.4.24;

contract FaceWorthPoll {

  uint constant STAKE = 100000000; // every participant stake 100 trx
  uint constant MIN_PARTICIPANTS = 10;
  uint constant MAX_PARTICIPANTS = 100000;
  uint constant WINNERS_RETURN = 3;   // DIST_PERCENTAGE * WINNERS_RETURN must be greater than 100,
  uint constant DIST_PERCENTAGE = 90; // so that winners prize is greater than the STAKE

  address public owner; // owner should be FaceWorthPollFactory contract
  address public initiator; // initiator is the one who wants to get his/her own FaceWorth
  bytes32 public faceHash; // face photo's SHA-256 hash
  uint public startingBlock;
  uint public endingBlock;
  bool public open;
  bool public prizeDistributed;

  mapping(address=>uint8) private worthBy;
  mapping(address=>bool) private evaluatedBy;
  uint private participantsRequired;
  address[] private participants;
  address[] private winners;

  constructor(address _initiator, bytes32 _faceHash, uint _endingBlock, uint _participantsRequired) public {
    owner = msg.sender;
    initiator = _initiator;
    faceHash = _faceHash;
    startingBlock = block.number;
    endingBlock = _endingBlock;
    participantsRequired = _participantsRequired;
    open = (participantsRequired >= MIN_PARTICIPANTS && participantsRequired <= MAX_PARTICIPANTS);
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
    require (!evaluatedBy[msg.sender]);
    _;
  }

  modifier prizeNotDistributed {
    require (!prizeDistributed);
    _;
  }

  function evaluate(uint8 _worth) payable external whenOpen onlyOnce {
    require(_worth >= 0 && _worth <=100);
    require(msg.value == STAKE);
    worthBy[msg.sender] = _worth;
    evaluatedBy[msg.sender] = true;
    participants.push(msg.sender);
    if (participants.length >= participantsRequired) {
      endPoll();
    } else {
      checkBlockNumber();
    }
  }

  function checkBlockNumber() public whenOpen {
    if (block.number >= endingBlock) {
      open = false;
      if (participants.length < participantsRequired) {
        refund();
      }
    }
  }

  function endPoll() private {
    open = false;

    // sort the participants by their worth from low to high using Counting Sort
    address[] memory sortedParticipants = sortParticipants();

    uint totalWorth = getTotalWorth();
    // find turning point where the right gives higher than average FaceWorth and the left lower
    uint turningPoint = getTurningPoint(totalWorth, sortedParticipants);

    // reverse those who give lower than average but the same FaceWorth so that the earlier participant is closer to the turning point
    uint p = turningPoint - 1;
    while (p > 0) {
      uint start = p;
      uint end = p;
      while (worthBy[sortedParticipants[start]] == worthBy[sortedParticipants[end - 1]]) {
        end = end - 1;
      }
      p = end - 1;
      while (start > end) {
        address tmp = sortedParticipants[start];
        sortedParticipants[start] = sortedParticipants[end];
        sortedParticipants[end] = tmp;
        start--;
        end++;
      }
    }

    findWinners(turningPoint, totalWorth, sortedParticipants);

    distributePrize();
  }

  function findWinners(uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    uint numOfWinners = participants.length / WINNERS_RETURN;
    uint index = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if(worthBy[_sortedParticipants[_turningPoint]] == _totalWorth) {
      winners[index] = _sortedParticipants[_turningPoint];
      index++;
      rightIndex++;
    } else {
      leftIndex--;
    }
    while (index < numOfWinners) {
      uint rightDiff;
      if (rightIndex < _sortedParticipants.length) {
        rightDiff = worthBy[_sortedParticipants[rightIndex]] * participants.length - _totalWorth;
      }
      uint leftDiff;
      if (leftIndex >= 0) {
        leftDiff = _totalWorth - worthBy[_sortedParticipants[leftIndex]] * participants.length;
      }
      if (leftIndex < 0 && rightIndex < _sortedParticipants.length
        || leftIndex >= 0 && rightIndex < _sortedParticipants.length && rightDiff <= leftDiff ) {
        winners[index] = _sortedParticipants[rightIndex];
        index++;
        rightIndex++;
      } else if (leftIndex >=0 && rightIndex >= _sortedParticipants.length
        || leftIndex >= 0 && rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        winners[index] = _sortedParticipants[leftIndex];
        index++;
        leftIndex--;
      } else {
        // should never be here, otherwise it's a bug!
        revert();
      }
    }
  }

  function distributePrize() private prizeNotDistributed {
    require(winners.length > 0);
    prizeDistributed = true;
    uint totalPrize = STAKE * participants.length * DIST_PERCENTAGE / 100;
    uint avgPrize = totalPrize / winners.length;
    uint minPrize = (avgPrize + 2 * STAKE) / 3;
    uint step = (avgPrize - minPrize) / (winners.length / 2);
    uint prize = minPrize;
    for (uint q = winners.length - 1; q > 0; q--) {
      winners[q].transfer(prize);
      prize += step;
    }
  }

  function sortParticipants() private view returns (address[] memory sortedParticipants_) {
    address[] memory sortedParticipants = new address[](participants.length);
    uint[101] memory count;
    for (uint i = 0; i < 101; i++) {
      count[i] = 0;
    }
    for (uint j = 0; j < participants.length; j++) {
      count[worthBy[participants[j]]]++;
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k-1];
    }
    for (uint m = participants.length-1; m >= 0; m--) {
      sortedParticipants[count[worthBy[participants[m]]] - 1] = participants[m];
      count[worthBy[participants[m]]]--;
    }

    // find turning point where the right gives higher than average FaceWorth and the left lower
    uint totalWorth = getTotalWorth();
    uint turningPoint;
    for (uint n = 0; n < sortedParticipants.length; n++) {
      if (worthBy[sortedParticipants[n]] * participants.length >= totalWorth) {
        turningPoint = n;
        break;
      }
    }
    return sortedParticipants;
  }

  function getTurningPoint(uint _totalWorth, address[] _sortedParticipants) private view returns (uint turningPoint_) {
    uint turningPoint;
    for (uint n = 0; n < _sortedParticipants.length; n++) {
      if (worthBy[_sortedParticipants[n]] * participants.length >= _totalWorth) {
        turningPoint = n;
        break;
      }
    }
    return turningPoint;
  }

  function getTotalWorth() private view returns (uint totalWorth_) {
    uint total = 0;
    for(uint i = 0; i < participants.length; i++) {
      total += worthBy[participants[i]];
    }
    return total;
  }

  function refund() private {
    for (uint i = 0; i < participants.length; i++) {
      participants[i].transfer(STAKE);
    }
  }

  function getParticipationProgress() external view returns (uint percentage_) {
    return participants.length * 100 / participantsRequired;
  }

  function getTimeElapsed() external view returns (uint percentage_) {
    return (block.number - startingBlock) * 100 / (endingBlock - block.number);
  }

  function getParticipants() external view whenClosed returns (address[] participants_) {
    return participants;
  }

  function getWorth(address _who) external view whenClosed returns (uint8 worth_) {
    return worthBy[_who];
  }

  function getWinners() external view whenClosed returns (address[] winners_) {
    return winners;
  }

  function () public payable {
    revert();
  }
}