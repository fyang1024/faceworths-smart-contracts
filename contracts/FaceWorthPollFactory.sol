pragma solidity >=0.4.23 <0.5.0;

import "./Owned.sol";
import "./FaceToken.sol";
import "./SafeMath.sol";

contract FaceWorthPollFactory is Owned {

  using SafeMath for uint256;

  uint8 public constant COMMITTING = 1;
  uint8 public constant REVEALING = 2;
  uint8 public constant CANCELLED = 3;
  uint8 public constant TIMEOUT = 4;
  uint8 public constant ENDED = 5;

  struct FaceWorthPoll {
    address creator;
    bytes32 faceHash;  // face photo's SHA-256 hash
    uint startBlock;
    uint commitEndBlock;
    uint revealEndBlock;
    uint8 currentStage;

    mapping(address => bytes32) saltedWorthHashBy;
    mapping(address => uint8) worthBy;
    mapping(address => bool) committedBy;
    mapping(address => bool) revealedBy;
    mapping(address => bool) refunded;
    mapping(address => bool) wonBy;
    address[] participants;
    address[] winners;
    uint revealCount;
    uint totalWorth;
  }

  uint public oneFace;
  uint public stake = 10**18; // every participant stake 1 ETH
  uint public minParticipants = 3;
  uint public maxParticipants = 618; // this number affects distributePrize algorithm's effectiveness
  uint public winnersPerThousand = 382; // 1000 * distPercentage / winnersPerThousand must be greater than 100,
  uint public distPercentage = 80; // so that winners prize is greater than the stake
  uint public minWaitBlocks = 10; // 10 blocks is about 30 seconds
  address public faceTokenAddress;
  uint256 public faceTokenRewardPool;

  bytes32[10] public topFaces;
  uint8 public topFaceCount = 0;
  address[10] public topWinners;
  uint8 public topWinnersCount = 0;
  mapping(address=>uint) public topWinnersRank;
  mapping(address=>uint) public prizeBy;
  mapping(bytes32 => FaceWorthPoll) public polls;
  bytes32[] pollHashes;

  constructor(address _faceTokenAddress) public {
    faceTokenAddress = _faceTokenAddress;
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceTokenRewardPool = faceToken.totalSupply() * 618 / 1000;
    oneFace = 10 ** faceToken.decimals();
  }

  event FaceWorthPollCreated (
    bytes32 indexed hash,
    address indexed creator,
    bytes32 indexed faceHash,
    uint startBlock,
    uint commitEndBlock,
    uint revealEndBlock
  );

  function createFaceWorthPoll(
    bytes32 _faceHash,
    uint _waitBlocks
  )
  public returns (bytes32)
  {
    require(_waitBlocks >= minWaitBlocks);

    bytes32 hash = keccak256(abi.encodePacked(msg.sender, _faceHash, block.number));
    polls[hash].creator = msg.sender;
    polls[hash].faceHash = _faceHash;
    polls[hash].startBlock = block.number;
    polls[hash].commitEndBlock = block.number + _waitBlocks;
    polls[hash].revealEndBlock = polls[hash].commitEndBlock + _waitBlocks;
    polls[hash].currentStage = COMMITTING;
    pollHashes.push(hash);

    emit FaceWorthPollCreated(
      hash,
      msg.sender,
      _faceHash,
      block.number,
      polls[hash].commitEndBlock,
      polls[hash].revealEndBlock
    );

    return hash;
  }

  function getPollCount() external view returns(uint) {
    return pollHashes.length;
  }

  function commit(bytes32 _hash, bytes32 _saltedWorthHash) payable external {
    require(!polls[_hash].committedBy[msg.sender]);
    require(polls[_hash].participants.length < maxParticipants);
    require(polls[_hash].currentStage == COMMITTING && msg.value == stake);

    polls[_hash].saltedWorthHashBy[msg.sender] = _saltedWorthHash;
    polls[_hash].committedBy[msg.sender] = true;
    polls[_hash].participants.push(msg.sender);
    emit Commit(_hash, msg.sender);
    if (polls[_hash].participants.length >= maxParticipants) {
      polls[_hash].currentStage = REVEALING;
      emit StageChange(_hash, REVEALING, COMMITTING, block.number);
    }
  }

  function reveal(bytes32 _hash, string _salt, uint8 _worth) external {
    require(polls[_hash].committedBy[msg.sender]);
    require(!polls[_hash].revealedBy[msg.sender]);
    require(polls[_hash].currentStage == REVEALING);
    require(_worth >= 0 && _worth <= 100);
    require(polls[_hash].saltedWorthHashBy[msg.sender] == keccak256(abi.encodePacked(concat(_salt, _worth))));

    polls[_hash].worthBy[msg.sender] = _worth;
    polls[_hash].revealedBy[msg.sender] = true;
    polls[_hash].revealCount++;
    polls[_hash].totalWorth += _worth;
    emit Reveal(_hash, msg.sender, _worth);
    if (polls[_hash].revealCount == polls[_hash].participants.length) {
      emit EarlyReveal(_hash, block.number, polls[_hash].revealEndBlock);
      polls[_hash].revealEndBlock = block.number;
    }
  }

  function cancel(bytes32 _hash) external {
    require(polls[_hash].creator == msg.sender);
    require(polls[_hash].currentStage == COMMITTING);

    polls[_hash].currentStage = CANCELLED;
    emit StageChange(_hash, CANCELLED, COMMITTING, block.number);
    refund(_hash);
  }

  function checkBlockNumber(bytes32 _hash) external {
    uint8 stage = polls[_hash].currentStage;
    if (stage != CANCELLED && stage != ENDED && stage != TIMEOUT) {
      if (block.number > polls[_hash].commitEndBlock) {
        if (polls[_hash].participants.length < minParticipants) {
          polls[_hash].currentStage = TIMEOUT;
          emit StageChange(_hash, TIMEOUT, COMMITTING, block.number);
          refund(_hash);
        } else if (block.number <= polls[_hash].revealEndBlock) {
          if (polls[_hash].currentStage != REVEALING) {
            polls[_hash].currentStage = REVEALING;
            emit StageChange(_hash, REVEALING, COMMITTING, block.number);
          }
        } else if(polls[_hash].currentStage != ENDED) {
          endPoll(_hash);
        }
      }
    }
  }

  function refund(bytes32 _hash) private {
    for (uint i = 0; i < polls[_hash].participants.length; i++) {
      if (!polls[_hash].refunded[polls[_hash].participants[i]]) {
        polls[_hash].refunded[polls[_hash].participants[i]] = true;
        polls[_hash].participants[i].transfer(stake);
        emit Refund(_hash, polls[_hash].participants[i], stake);
      }
    }
  }

  function endPoll(bytes32 _hash) private {
    polls[_hash].currentStage = ENDED;

    if (polls[_hash].revealCount > 0) {
      // sort the participants by their worth from low to high using Counting Sort
      address[] memory sortedParticipants = sortParticipants(_hash);

      // find turning point where the right gives higher than average FaceWorth and the left lower
      uint turningPoint = getTurningPoint(_hash, polls[_hash].totalWorth, sortedParticipants);

      // reverse those who give lower than average but the same FaceWorth so that the earlier participant is closer to the turning point
      if (turningPoint > 0) {
        uint p = turningPoint - 1;
        while (p > 0) {
          uint start = p;
          uint end = p;
          while (end > 0 && polls[_hash].worthBy[sortedParticipants[start]] == polls[_hash].worthBy[sortedParticipants[end - 1]]) {
            end = end - 1;
          }

          if (end > 1) p = end - 1;
          else p = 0;

          while (start > end) {
            address tmp = sortedParticipants[start];
            sortedParticipants[start] = sortedParticipants[end];
            sortedParticipants[end] = tmp;
            start--;
            end++;
          }
        }
      }

      findWinners(_hash, turningPoint, polls[_hash].totalWorth, sortedParticipants);

      distributePrize(_hash);

      reorderTopWinners(_hash);

      reorderTopFaces(_hash);
    }

    rewardFaceTokens(_hash);

    emit StageChange(_hash, ENDED, REVEALING, block.number);
  }

  function rewardFaceTokens(bytes32 _hash) private {
    if (faceTokenRewardPool > 0) {
      uint creatorReward = oneFace + oneFace * polls[_hash].participants.length * 382 / 10000;
      if (faceTokenRewardPool < creatorReward) {
        creatorReward = faceTokenRewardPool;
      }
      rewardFaceTokens(polls[_hash].creator, creatorReward);
      if (faceTokenRewardPool > 0) {
        uint participantReward = oneFace * 618 / 1000;
        for (uint i = 0; i < polls[_hash].participants.length; i++) {
          if (!polls[_hash].wonBy[polls[_hash].participants[i]]) {
            if (faceTokenRewardPool < participantReward) {
              rewardFaceTokens(polls[_hash].participants[i], faceTokenRewardPool);
              break;
            } else {
              rewardFaceTokens(polls[_hash].participants[i], participantReward);
            }
          }
        }
      }
    }
  }

  function rewardFaceTokens(address _receiver, uint _value) private {
    faceTokenRewardPool = faceTokenRewardPool.sub(_value);
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceToken.increaseApproval(_receiver, _value);
  }

  function findWinners(bytes32 _hash, uint _turningPoint, uint _totalWorth, address[] memory _sortedParticipants) private {
    uint numOfWinners = polls[_hash].participants.length * winnersPerThousand / 1000;
    if (numOfWinners > polls[_hash].revealCount) numOfWinners = polls[_hash].revealCount;
    uint count = 0;
    uint leftIndex = _turningPoint;
    uint rightIndex = _turningPoint;
    if (polls[_hash].worthBy[_sortedParticipants[_turningPoint]] * polls[_hash].revealCount == _totalWorth) {
      polls[_hash].winners.push(_sortedParticipants[_turningPoint]);
      polls[_hash].wonBy[_sortedParticipants[_turningPoint]] = true;
      emit Win(_hash, _sortedParticipants[_turningPoint], polls[_hash].worthBy[_sortedParticipants[_turningPoint]]);
      count++;
      rightIndex++;
      if (leftIndex > 0) leftIndex--;
    } else {
      if (leftIndex > 0) leftIndex--;
      else rightIndex++;
    }
    while (count < numOfWinners) {
      uint rightDiff;
      if (rightIndex < _sortedParticipants.length) {
        rightDiff = polls[_hash].worthBy[_sortedParticipants[rightIndex]] * polls[_hash].revealCount - _totalWorth;
      }
      uint leftDiff = _totalWorth - polls[_hash].worthBy[_sortedParticipants[leftIndex]] * polls[_hash].revealCount;
      if (rightIndex < _sortedParticipants.length && rightDiff <= leftDiff) {
        polls[_hash].winners.push(_sortedParticipants[rightIndex]);
        polls[_hash].wonBy[_sortedParticipants[rightIndex]] = true;
        emit Win(_hash, _sortedParticipants[rightIndex], polls[_hash].worthBy[_sortedParticipants[rightIndex]]);
        count++;
        rightIndex++;
      } else if (rightIndex >= _sortedParticipants.length || rightIndex < _sortedParticipants.length && rightDiff > leftDiff) {
        polls[_hash].winners.push(_sortedParticipants[leftIndex]);
        polls[_hash].wonBy[_sortedParticipants[leftIndex]] = true;
        emit Win(_hash, _sortedParticipants[leftIndex], polls[_hash].worthBy[_sortedParticipants[leftIndex]]);
        count++;
        if (leftIndex > 0) leftIndex--;
        else rightIndex++;
      }
    }
  }

  function distributePrize(bytes32 _hash) private {
    uint totalPrize = stake * polls[_hash].participants.length * distPercentage / 100;
    uint winnerCount = polls[_hash].winners.length;
    if (winnerCount == 1) {
      prizeBy[polls[_hash].winners[0]] += totalPrize;
      polls[_hash].winners[0].transfer(totalPrize);
    } else {
      uint minLowestPrize = stake + (stake / 10);
      uint maxStep = (totalPrize * 2 - 2 * minLowestPrize * winnerCount)  / (winnerCount ** 2 - winnerCount);
      uint step;
      if (maxStep <= 2) {
        step = maxStep;
      } else  {
        step = (1 + maxStep) / 2;
        if (step > stake) {
          step = stake;
        }
      }
      uint lowestPrize = (totalPrize * 2 + step * winnerCount - step * (winnerCount ** 2)) / (2 * winnerCount);
      uint prize = lowestPrize;
      for (uint i = winnerCount; i > 0; i--) {
        prizeBy[polls[_hash].winners[i - 1]] += prize;
        polls[_hash].winners[i - 1].transfer(prize);
        prize += step;
      }
    }
  }

  function reorderTopWinners(bytes32 _hash) private {
    for (uint i = 0; i < polls[_hash].winners.length; i++) {
      uint currentRank = topWinnersRank[polls[_hash].winners[i]];
      if (currentRank > 0) { // already top winners
        if (currentRank > 1 && prizeBy[topWinners[currentRank - 1]] > prizeBy[topWinners[currentRank - 2]]) {
          for (uint p = currentRank - 1; p > 0; p--) {
            if (prizeBy[topWinners[p]] > prizeBy[topWinners[p - 1]]) {
              topWinners[p] = topWinners[p - 1];
              topWinnersRank[topWinners[p]] = p + 1;
              topWinners[p-1] = polls[_hash].winners[i];
              topWinnersRank[topWinners[p - 1]] = p;
            } else {
              break;
            }
          }
        } else {
          for (uint q = currentRank - 1; q < topWinnersCount - 1; q++) {
            if (prizeBy[topWinners[q]] < prizeBy[topWinners[q + 1]]) {
              topWinners[q] = topWinners[q + 1];
              topWinnersRank[topWinners[q]] = q + 1;
              topWinners[q + 1] = polls[_hash].winners[i];
              topWinnersRank[topWinners[q + 1]] = q + 2;
            } else {
              break;
            }
          }
        }
      } else {
        bool inserted = false;
        for (uint j = 0; j < topWinnersCount; j++) {
          if (prizeBy[polls[_hash].winners[i]] >= prizeBy[topWinners[j]]) {
            if (topWinnersCount == topWinners.length) {
              topWinnersRank[topWinners[topWinnersCount - 1]] = 0;
            }
            if (topWinnersCount < topWinners.length) {
              topWinnersCount++;
            }
            for (uint k = topWinnersCount - 1; k > j; k--) {
              topWinners[k] = topWinners[k - 1];
              topWinnersRank[topWinners[k]] = k + 1;
            }
            topWinners[j] = polls[_hash].winners[i];
            topWinnersRank[topWinners[j]] = j + 1;
            inserted = true;
            break;
          }
        }
        if (!inserted && topWinnersCount < topWinners.length) {
          topWinners[topWinnersCount] = polls[_hash].winners[i];
          topWinnersRank[topWinners[topWinnersCount]] = topWinnersCount + 1;
          topWinnersCount++;
        }
      }
    }
  }

  function reorderTopFaces(bytes32 _hash) private {
    bool inserted = false;
    for (uint i = 0; i < topFaceCount; i++) {
      if (compareScore(_hash, topFaces[i]) >= 0) {
        if (topFaceCount < topFaces.length) {
          topFaceCount++;
        }
        for (uint j = topFaceCount - 1; j > i; j--) {
          topFaces[j] = topFaces[j - 1];
        }
        topFaces[i] = _hash;
        inserted = true;
        break;
      }
    }
    if (!inserted && topFaceCount < topFaces.length) {
      topFaces[topFaceCount] = _hash;
      topFaceCount++;
    }
  }

  function sqrt(uint x) private pure returns (uint y) {
    if (x == 0) return 0;
    else if (x <= 3) return 1;
    uint z = (x + 1) / 2;
    y = x;
    while (z < y) {
      y = z;
      z = (x / z + z) / 2;
    }
  }

  function compareScore(bytes32 _hash1, bytes32 _hash2) private view returns (int) {
    uint score1 = polls[_hash1].totalWorth * polls[_hash2].revealCount * sqrt(polls[_hash1].participants.length * 10);
    uint score2 = polls[_hash2].totalWorth * polls[_hash1].revealCount * sqrt(polls[_hash2].participants.length * 10);
    if (score1 == score2) {
      if (polls[_hash1].participants.length > polls[_hash2].participants.length) {
        return 1;
      } else if (polls[_hash1].participants.length == polls[_hash2].participants.length) {
        return 0;
      } else {
        return -1;
      }
    } else {
      if (score1 > score2) {
        return 1;
      } else if (score1 == score2) {
        return 0;
      } else {
        return -1;
      }
    }
  }

  function sortParticipants(bytes32 _hash) private view returns (address[]) {
    address[] memory sortedParticipants_ = new address[](polls[_hash].revealCount);
    uint[101] memory count;
    for (uint i = 0; i < 101; i++) {
      count[i] = 0;
    }
    for (uint j = 0; j < polls[_hash].participants.length; j++) {
      if (polls[_hash].revealedBy[polls[_hash].participants[j]]) {
        count[polls[_hash].worthBy[polls[_hash].participants[j]]]++;
      }
    }
    for (uint k = 1; k < 101; k++) {
      count[k] += count[k - 1];
    }
    for (uint m = polls[_hash].participants.length; m > 0; m--) {
      if (polls[_hash].revealedBy[polls[_hash].participants[m - 1]]) {
        sortedParticipants_[count[polls[_hash].worthBy[polls[_hash].participants[m - 1]]] - 1] = polls[_hash].participants[m - 1];
        count[polls[_hash].worthBy[polls[_hash].participants[m - 1]]]--;
      }
    }
    return sortedParticipants_;
  }

  function getTurningPoint(bytes32 _hash, uint _totalWorth, address[] _sortedParticipants) private view returns (uint) {
    uint turningPoint_;
    for (uint i = 0; i < _sortedParticipants.length; i++) {
      if (polls[_hash].worthBy[_sortedParticipants[i]] * polls[_hash].revealCount >= _totalWorth) {
        turningPoint_ = i;
        break;
      }
    }
    return turningPoint_;
  }

  function getStatus(bytes32 _hash) external view
  returns (
    address creator,
    uint startBlock,
    uint commitEndBlock,
    uint revealEndBlock,
    uint currentBlock,
    uint8 currentStage,
    uint participantCount,
    uint revealCount,
    uint totalWorth
  )
  {
    creator = polls[_hash].creator;
    startBlock = polls[_hash].startBlock;
    commitEndBlock = polls[_hash].commitEndBlock;
    revealEndBlock = polls[_hash].revealEndBlock;
    currentBlock = block.number;
    currentStage = polls[_hash].currentStage;
    participantCount = polls[_hash].participants.length;
    revealCount = polls[_hash].revealCount;
    totalWorth = polls[_hash].totalWorth;
  }

  function getCurrentBlock() external view returns (uint) {
    return block.number;
  }

  function getCurrentStage(bytes32 _hash) external view returns (uint8) {
    return polls[_hash].currentStage;
  }

  function getParticipantCount(bytes32 _hash) external view returns (uint) {
    return polls[_hash].participants.length;
  }

  function getParticipants(bytes32 _hash) external view returns (address[] memory) {
    require(polls[_hash].currentStage != COMMITTING);
    return polls[_hash].participants;
  }

  function getWorthBy(bytes32 _hash, address _who) external view returns (uint8) {
    require(polls[_hash].currentStage == ENDED);
    return polls[_hash].worthBy[_who];
  }

  function getWinnerCount(bytes32 _hash) external view returns (uint) {
    require(polls[_hash].currentStage == ENDED);
    return polls[_hash].winners.length;
  }

  function getWinners(bytes32 _hash) external view returns (address[] memory) {
    require(polls[_hash].currentStage == ENDED);
    return polls[_hash].winners;
  }

  function getPrize(address winner) external view returns (uint) {
    return prizeBy[winner];
  }

  function concat(string _str, uint8 _v) private pure returns (string) {
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
    return string(s);
  }


  function updateStake(uint _stake) external onlyOwner {
    require(_stake != stake);
    uint oldStake = stake;
    stake = _stake;
    emit StakeUpdate(stake, oldStake);
  }

  function updateRewardRatios(uint _winnersPerThousand, uint _distPercentage) external onlyOwner {
    require(_distPercentage <= 100);
    require(_winnersPerThousand < 1000);
    require(1000 * _distPercentage / _winnersPerThousand >= 100);
    require(_winnersPerThousand != winnersPerThousand || _distPercentage != distPercentage);

    if (_winnersPerThousand != winnersPerThousand) {
      uint oldWinnersReturn = winnersPerThousand;
      winnersPerThousand = _winnersPerThousand;
      emit RewardRatiosUpdate(winnersPerThousand, oldWinnersReturn);
    }
    if (_distPercentage != distPercentage) {
      uint oldDistPercentage = distPercentage;
      distPercentage = _distPercentage;
      emit DistPercentageUpdate(distPercentage, oldDistPercentage);
    }
  }

  function updateMinWaitBlocks(uint _minWaitBlocks) external onlyOwner {
    require(_minWaitBlocks != minWaitBlocks);
    uint oldMinWaitBlocks = minWaitBlocks;
    minWaitBlocks = _minWaitBlocks;
    emit MinWaitBlocksUpdate(minWaitBlocks, oldMinWaitBlocks);
  }

  function withdraw(uint _amount) external onlyOwner {
    require(address(this).balance >= _amount);
    msg.sender.transfer(_amount);
  }

  event StakeUpdate(uint newStake, uint oldStake);

  event RewardRatiosUpdate(uint newWinnersPerThousand, uint oldWinnersPerThousand);

  event DistPercentageUpdate(uint newDistPercentage, uint oldDistPercentage);

  event MinWaitBlocksUpdate(uint newMinWaitBlocks, uint oldMinWaitBlocks);

  event StageChange(bytes32 hash, uint8 newStage, uint8 oldStage, uint blockNumber);

  event Refund(bytes32 hash, address recepient, uint fund);

  event Commit(bytes32 hash, address committer);

  event Reveal(bytes32 hash, address revealor, uint8 worth);

  event Win(bytes32 hash, address winner, uint8 worth);

  event EarlyReveal(bytes32 hash, uint newRevealEndBlock, uint oldRevealEndBlock);
}
