pragma solidity ^0.4.23;
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

  mapping(address=>bytes32) private saltedWorthHashBy;
  mapping(address=>uint8) private worthBy;
  mapping(address=>bool) private committedBy;
  mapping(address=>bool) private revealedBy;
  mapping(address=>bool) private withdrawnBy;
  mapping(address=>bool) private wonBy;
  uint private participantsRequired;
  address[] private participants;
  address[] private winners;
  uint revealCount;

  enum Stage { COMMITTING, REVEALING, CANCELLED, ENDED }

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
    oneFace = 10**_faceTokenDecimals;
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
    require (msg.sender == initiator);
    _;
  }

  modifier committedByMe {
    require (committedBy[msg.sender]);
    _;
  }

  modifier notCommittedByMe {
    require (!committedBy[msg.sender]);
    _;
  }

  modifier notRevealedByMe {
    require (!revealedBy[msg.sender]);
    _;
  }

  event StageChange(Stage newStage, Stage oldStage);

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

  function reveal(uint8 _worth, bytes32 _salt)
    external
    committedByMe
    notRevealedByMe
  {
    require(currentStage == Stage.REVEALING && saltedWorthHashBy[msg.sender] != keccak256(abi.encodePacked(_worth, _salt)));
    worthBy[msg.sender] = _worth;
    revealCount++;
  }

  function withdraw() external {
    require(currentStage == Stage.CANCELLED && committedBy[msg.sender] && !withdrawnBy[msg.sender]);
    withdrawnBy[msg.sender] = true;
    msg.sender.transfer(stake);
  }

  function cancel() external onlyInitiator {
    require (currentStage == Stage.COMMITTING);
    currentStage = Stage.CANCELLED;
    emit StageChange(currentStage, Stage.COMMITTING);
  }

  // this function should be called every 3 seconds (Tron block time) by FacesWorths
  function checkBlockNumber() external {
    if (currentStage != Stage.CANCELLED && currentStage != Stage.ENDED) {
      if (block.number > commitEndingBlock) {
        if (participants.length < participantsRequired) {
          currentStage = Stage.CANCELLED;
          emit StageChange(currentStage, Stage.COMMITTING);
        } else if (block.number <= revealEndingBlock) {
          currentStage = Stage.REVEALING;
          emit StageChange(currentStage, Stage.COMMITTING);
        } else {
          endPoll();
        }
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
          if(!wonBy[participants[i]]) {
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
    emit StageChange(currentStage, Stage.REVEALING);
  }

  function findWinners(uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    uint numOfWinners = participants.length / winnersReturn;
    if (numOfWinners > revealCount) numOfWinners = revealCount;
    uint index = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if(worthBy[_sortedParticipants[_turningPoint]] == _totalWorth) {
      winners[index] = _sortedParticipants[_turningPoint];
      wonBy[winners[index]] = true;
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
        wonBy[winners[index]] = true;
        index++;
        rightIndex++;
      } else if (leftIndex >=0 && rightIndex >= _sortedParticipants.length
        || leftIndex >= 0 && rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        winners[index] = _sortedParticipants[leftIndex];
        wonBy[winners[index]] = true;
        index++;
        leftIndex--;
      } else {
        // should never be here, otherwise it's a bug!
        revert();
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
    for (uint q = winners.length - 1; q > 0; q--) {
      winners[q].transfer(prize);
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
      if(revealedBy[participants[j]]) {
        count[worthBy[participants[j]]]++;
      }
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k-1];
    }
    for (uint m = participants.length-1; m >= 0; m--) {
      if(revealedBy[participants[m]]) {
        sortedParticipants_[count[worthBy[participants[m]]] - 1] = participants[m];
        count[worthBy[participants[m]]]--;
      }
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
    require (currentStage != Stage.COMMITTING && currentStage != Stage.CANCELLED);
    participants_ = participants;
  }

  function getWorth(address _who) external view returns (uint8 worth_) {
    require (currentStage == Stage.ENDED);
    worth_ = worthBy[_who];
  }

  function getWinners() external view returns (address[] winners_) {
    require (currentStage == Stage.ENDED);
    winners_ = winners;
  }

  function () public payable {
    revert();
  }
}