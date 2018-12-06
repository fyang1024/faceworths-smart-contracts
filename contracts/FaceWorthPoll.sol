pragma solidity ^0.4.24;

import "./FaceWorthPollFactory.sol";

contract FaceWorthPoll {

  uint public stake;
  uint public winnersReturn;
  uint public distPercentage;
  uint public oneFace;
  address public factoryAddress;
  address public initiator; // initiator is the one who wants to get his/her own FaceWorth
  bytes32 public faceHash; // face photo's SHA-256 hash
  uint public startingBlock;
  uint public commitEndingBlock;
  uint public revealEndingBlock;
  Stage public currentStage;

  mapping(address => bytes32) private saltedWorthHashBy;
  mapping(address => uint8) private worthBy;
  mapping(address => bool) private committedBy;
  mapping(address => bool) private revealedBy;
  mapping(address => bool) private refunded;
  mapping(address => bool) private wonBy;
  uint private participantsRequired;
  address[] private participants;
  address[] private winners;
  uint revealCount;

  enum Stage {COMMITTING, REVEALING, CANCELLED, ENDED}

  constructor(
    address _factoryAddress,
    uint _faceTokenDecimals,
    address _initiator,
    bytes32 _faceHash,
    uint _blocksBeforeReveal,
    uint _blocksBeforeEnd,
    uint _participantsRequired,
    uint _stake,
    uint _winnersReturn,
    uint _distPercentage
  ) public {
    factoryAddress = _factoryAddress;
    oneFace = 10 ** _faceTokenDecimals;
    initiator = _initiator;
    faceHash = _faceHash;
    startingBlock = block.number;
    commitEndingBlock = startingBlock + _blocksBeforeReveal;
    revealEndingBlock = commitEndingBlock + _blocksBeforeEnd;
    participantsRequired = _participantsRequired;
    stake = _stake;
    winnersReturn = _winnersReturn;
    distPercentage = _distPercentage;
    currentStage = Stage.COMMITTING;
    revealCount = 0;
  }

  modifier onlyInitiator {
    require(msg.sender == initiator);
    _;
  }

  modifier committedByMe {
    require(committedBy[msg.sender]);
    _;
  }

  modifier notCommittedByMe {
    require(!committedBy[msg.sender]);
    _;
  }

  modifier notRevealedByMe {
    require(!revealedBy[msg.sender]);
    _;
  }

  event StageChange(Stage newStage, Stage oldStage);

  event Refund(address recepient, uint fund);

  function commit(bytes32 _saltedWorthHash)
    payable
    external
    notCommittedByMe
  {
    require(currentStage == Stage.COMMITTING && msg.value == stake);
    saltedWorthHashBy[msg.sender] = _saltedWorthHash;
    committedBy[msg.sender] = true;
    participants.push(msg.sender);
  }

  function reveal(string _salt, uint8 _worth)
    external
    committedByMe
    notRevealedByMe
  {
    require(currentStage == Stage.REVEALING);
    require(saltedWorthHashBy[msg.sender] == keccak256(abi.encodePacked(concat(_salt, _worth))));
    require(_worth >= 0 && _worth <= 100);
    worthBy[msg.sender] = _worth;
    revealedBy[msg.sender] = true;
    revealCount++;
  }

  function cancel() external onlyInitiator {
    require(currentStage == Stage.COMMITTING);
    currentStage = Stage.CANCELLED;
    emit StageChange(currentStage, Stage.COMMITTING);
    refund();
  }

  // this function should be called every 3 seconds (Tron block time)
  function checkBlockNumber() external {
    if (currentStage != Stage.CANCELLED && currentStage != Stage.ENDED) {
      if (block.number > commitEndingBlock) {
        if (participants.length < participantsRequired) {
          currentStage = Stage.CANCELLED;
          emit StageChange(currentStage, Stage.COMMITTING);
          refund();
        } else if (block.number <= revealEndingBlock) {
          currentStage = Stage.REVEALING;
          emit StageChange(currentStage, Stage.COMMITTING);
        } else {
          endPoll();
        }
      }
    }
  }

  function refund() private {
    require(currentStage == Stage.CANCELLED);
    for (uint i = 0; i < participants.length; i++) {
      if (!refunded[participants[i]]) {
        refunded[participants[i]] = true;
        participants[i].transfer(stake);
        emit Refund(participants[i], stake);
      }
    }
  }

  function endPoll() private {
    require(currentStage != Stage.ENDED);
    currentStage = Stage.ENDED;

    if (revealCount > 0) {
      // sort the participants by their worth from low to high using Counting Sort
      address[] memory sortedParticipants = sortParticipants();

      uint totalWorth = getTotalWorth();
      // find turning point where the right gives higher than average FaceWorth and the left lower
      uint turningPoint = getTurningPoint(totalWorth, sortedParticipants);

      // reverse those who give lower than average but the same FaceWorth so that the earlier participant is closer to the turning point
      if (turningPoint > 0) {
        uint p = turningPoint - 1;
        while (p > 0) {
          uint start = p;
          uint end = p;
          while (end > 0 && worthBy[sortedParticipants[start]] == worthBy[sortedParticipants[end - 1]]) {
            end = end - 1;
          }
          if (end > 0) p = end - 1;
          while (start > end) {
            address tmp = sortedParticipants[start];
            sortedParticipants[start] = sortedParticipants[end];
            sortedParticipants[end] = tmp;
            start--;
            end++;
          }
        }
      }

      findWinners(turningPoint, totalWorth, sortedParticipants);

      distributePrize();
    }

    rewardFaceTokens();

    emit StageChange(currentStage, Stage.REVEALING);
  }

  function rewardFaceTokens() private {
    FaceWorthPollFactory factory = FaceWorthPollFactory(factoryAddress);
    if (factory.faceTokenRewardPool() > 0) {
      uint initiatorReward = oneFace + oneFace * participants.length / 10;
      if (factory.faceTokenRewardPool() < initiatorReward) {
        initiatorReward = factory.faceTokenRewardPool();
      }
      factory.rewardFaceTokens(initiator, initiatorReward);
      if (factory.faceTokenRewardPool() > 0) {
        uint participantReward = oneFace / 10;
        for (uint i = 0; i < participants.length; i++) {
          if (!wonBy[participants[i]]) {
            if (factory.faceTokenRewardPool() < participantReward) {
              factory.rewardFaceTokens(participants[i], factory.faceTokenRewardPool());
              break;
            } else {
              factory.rewardFaceTokens(participants[i], participantReward);
            }
          }
        }
      }
    }
  }

  function findWinners(uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    uint numOfWinners = participants.length * 1000 / winnersReturn;
    if (numOfWinners > revealCount) numOfWinners = revealCount;
    uint index = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if (worthBy[_sortedParticipants[_turningPoint]] * revealCount == _totalWorth) {
      winners.push(_sortedParticipants[_turningPoint]);
      wonBy[winners[index]] = true;
      index++;
      rightIndex++;
    } else {
      if (leftIndex > 0) leftIndex--;
      else rightIndex++;
    }
    while (index < numOfWinners) {
      uint rightDiff;
      if (rightIndex < _sortedParticipants.length) {
        rightDiff = worthBy[_sortedParticipants[rightIndex]] * revealCount - _totalWorth;
      }
      uint leftDiff = _totalWorth - worthBy[_sortedParticipants[leftIndex]] * revealCount;

      if (rightIndex < _sortedParticipants.length && rightDiff <= leftDiff) {
        winners.push(_sortedParticipants[rightIndex]);
        wonBy[_sortedParticipants[rightIndex]] = true;
        index++;
        rightIndex++;
      } else if (rightIndex >= _sortedParticipants.length || rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        winners.push(_sortedParticipants[leftIndex]);
        wonBy[_sortedParticipants[leftIndex]] = true;
        index++;
        if (leftIndex > 0) leftIndex--;
        else rightIndex++;
      }
    }
  }

  function distributePrize() private {
    require(winners.length > 0);
    uint totalPrize = stake * participants.length * distPercentage / 100;
    uint avgPrize = totalPrize / winners.length;
    uint minPrize = (avgPrize + 2 * stake) / 3;
    uint step = (avgPrize - minPrize) / (winners.length / 2);
    uint prize = minPrize;
    for (uint q = winners.length; q > 0; q--) {
      winners[q - 1].transfer(prize);
      prize += step;
    }
  }

  function sortParticipants() private view returns (address[] memory sortedParticipants_) {
    sortedParticipants_ = new address[](revealCount);
    uint[101] memory count;
    for (uint i = 0; i < 101; i++) {
      count[i] = 0;
    }
    for (uint j = 0; j < participants.length; j++) {
      if (revealedBy[participants[j]]) {
        count[worthBy[participants[j]]]++;
      }
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k - 1];
    }
    for (uint m = participants.length; m > 0; m--) {
      if (revealedBy[participants[m - 1]]) {
        sortedParticipants_[count[worthBy[participants[m - 1]]] - 1] = participants[m - 1];
        count[worthBy[participants[m - 1]]]--;
      }
    }
  }

  function getTurningPoint(uint _totalWorth, address[] _sortedParticipants) private view returns (uint turningPoint_) {
    turningPoint_;
    for (uint i = 0; i < _sortedParticipants.length; i++) {
      if (worthBy[_sortedParticipants[i]] * revealCount >= _totalWorth) {
        turningPoint_ = i;
        break;
      }
    }
  }

  function getTotalWorth() private view returns (uint totalWorth_) {
    totalWorth_ = 0;
    for (uint i = 0; i < participants.length; i++) {
      if (revealedBy[participants[i]]) {
        totalWorth_ += worthBy[participants[i]];
      }
    }
  }

  function getCommitTimeElapsed() external view returns (uint percentage_) {
    percentage_ = (block.number - startingBlock) * 100 / (commitEndingBlock - startingBlock);
  }

  function getRevealTimeElapsed() external view returns (uint percentage_) {
    if (block.number < commitEndingBlock) {
      percentage_ = 0;
    } else {
      percentage_ = (block.number - commitEndingBlock - 1) * 100 / (revealEndingBlock - commitEndingBlock - 1);
    }
  }

  function getNumberOfParticipants() external view onlyInitiator returns (uint n_) {
    n_ = participants.length;
  }

  function getParticipantsRequired() external view onlyInitiator returns (uint n_) {
    n_ = participantsRequired;
  }

  function getParticipants() external view returns (address[] participants_) {
    require(currentStage != Stage.COMMITTING && currentStage != Stage.CANCELLED);
    participants_ = participants;
  }

  function getWorthBy(address _who) external view returns (uint8 worth_) {
    require(currentStage == Stage.ENDED);
    worth_ = worthBy[_who];
  }

  function getWinners() external view returns (address[] winners_) {
    require(currentStage == Stage.ENDED);
    winners_ = winners;
  }

  function() public payable {
    revert();
  }

  function concat(string _str, uint8 _v) private pure returns (string str_) {
    uint maxLength = 3;
    bytes memory reversed = new bytes(maxLength);
    uint i = 0;
    do {
      uint remainder = _v % 10;
      _v = _v / 10;
      reversed[i++] = byte(48 + remainder);
    }
    while (_v != 0);

    bytes memory concatenated = bytes(_str);
    bytes memory s = new bytes(concatenated.length + i);
    uint j;
    for (j = 0; j < concatenated.length; j++) {
      s[j] = concatenated[j];
    }
    for (j = 0; j < i; j++) {
      s[j + concatenated.length] = reversed[i - 1 - j];
    }
    str_ = string(s);
  }
}