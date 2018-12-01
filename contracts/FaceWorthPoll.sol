pragma solidity ^0.4.24;

contract FaceWorthPoll {

  uint public stake;
  uint public winnersReturn;
  uint public distPercentage;

  address public initiator; // initiator is the one who wants to get his/her own FaceWorth
  bytes32 public faceHash; // face photo's SHA-256 hash
  uint public startingBlock;
  uint public commitEndingBlock;
  uint public revealEndingBlock;
  bool public prizeDistributed;

  mapping(address=>bytes32) private saltedWorthHashBy;
  mapping(address=>uint8) private worthBy;
  mapping(address=>bool) private scoredBy;
  uint private participantsRequired;
  address[] private participants;
  address[] private winners;

  constructor(
    address _initiator,
    bytes32 _faceHash,
    uint _blocksBeforeReveal,
    uint _blocksBeforeEnd,
    uint _participantsRequired,
    uint _stake,
    uint _winnersReturn,
    uint _distPercentage
  ) public {
    initiator = _initiator;
    faceHash = _faceHash;
    startingBlock = block.number;
    commitEndingBlock = startingBlock + _blocksBeforeReveal;
    revealEndingBlock = commitEndingBlock + _blocksBeforeEnd;
    participantsRequired = _participantsRequired;
    stake = _stake;
    winnersReturn = _winnersReturn;
    distPercentage = _distPercentage;
    prizeDistributed = false;
  }

  modifier committing {
    require (block.number <= commitEndingBlock);
    _;
  }

  modifier revealing {
    require (block.number > commitEndingBlock && block.number <= revealEndingBlock);
    _;
  }

  modifier revealed {
    require (block.number > revealEndingBlock);
    _;
  }

  modifier onlyOnce {
    require (!scoredBy[msg.sender]);
    _;
  }

  modifier prizeNotDistributed {
    require (!prizeDistributed);
    _;
  }

  function commit(bytes32 _saltedWorthHash) payable external committing onlyOnce {
    require(msg.value == stake);
    saltedWorthHashBy[msg.sender] = _saltedWorthHash;
    scoredBy[msg.sender] = true;
    participants.push(msg.sender);
  }

  function reveal(uint8 _worth, bytes32 _salt) external revealing {
    require(saltedWorthHashBy[msg.sender] != keccak256(abi.encodePacked(_worth, salt)));
    worthBy[msg.sender] = _worth;
  }

  function checkBlockNumber() public {
    if (block.number > commitEndingBlock) {
      if (participants.length < participantsRequired) {
        refund();
      }
    }
  }

  function endPoll() private {

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
    uint numOfWinners = participants.length / winnersReturn;
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
    uint totalPrize = stake * participants.length * distPercentage / 100;
    uint avgPrize = totalPrize / winners.length;
    uint minPrize = (avgPrize + 2 * stake) / 3;
    uint step = (avgPrize - minPrize) / (winners.length / 2);
    uint prize = minPrize;
    for (uint q = winners.length - 1; q > 0; q--) {
      winners[q].transfer(prize);
      prize += step;
    }
  }

  function sortParticipants() private view returns (address[] memory sortedParticipants_) {
    sortedParticipants_ = new address[](participants.length);
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
      sortedParticipants_[count[worthBy[participants[m]]] - 1] = participants[m];
      count[worthBy[participants[m]]]--;
    }
  }

  function getTurningPoint(uint _totalWorth, address[] _sortedParticipants) private view returns (uint turningPoint_) {
    turningPoint_;
    for (uint n = 0; n < _sortedParticipants.length; n++) {
      if (worthBy[_sortedParticipants[n]] * participants.length >= _totalWorth) {
        turningPoint_ = n;
        break;
      }
    }
  }

  function getTotalWorth() private view returns (uint totalWorth_) {
    totalWorth_ = 0;
    for(uint i = 0; i < participants.length; i++) {
      totalWorth_ += worthBy[participants[i]];
    }
  }

  function refund() private {
    for (uint i = 0; i < participants.length; i++) {
      participants[i].transfer(stake);
    }
  }

  function getParticipationProgress() external view returns (uint percentage_) {
    percentage_ = participants.length * 100 / participantsRequired;
  }

  function getTimeElapsed() external view returns (uint percentage_) {
    percentage_ = (block.number - startingBlock) * 100 / (commitEndingBlock - block.number);
  }

  function getParticipants() external view returns (address[] participants_) {
    participants_ = participants;
  }

  function getWorth(address _who) external view returns (uint8 worth_) {
    worth_ = worthBy[_who];
  }

  function getWinners() external view returns (address[] winners_) {
    winners_ = winners;
  }

  function () public payable {
    revert();
  }
}