pragma solidity ^0.4.24;

import "./Owned.sol";
import "./FaceWorthPoll.sol";
import "./FaceToken.sol";
import "./SafeMath.sol";

contract FaceWorthPollFactory is Owned {

  using SafeMath for uint256;

  uint public stake = 10**18; // every participant stake 1 ETH
  uint public minParticipants = 3;
  uint public maxParticipants = 10000;
  uint public winnersPerThousand = 382;   // 1000 * distPercentage / winnersPerThousand must be greater than 100,
  uint public distPercentage = 90; // so that winners prize is greater than the stake
  uint public minBlocksBeforeReveal = 10; // 10 blocks is about 30 seconds
  uint public minBlocksBeforeEnd = 10;
  uint256 public faceTokenRewardPool;

  address public faceTokenAddress;

  mapping(address => bool) deployed;

  address[] deployedPolls;

  constructor(address _faceTokenAddress) public {
    faceTokenAddress = _faceTokenAddress;
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceTokenRewardPool = faceToken.totalSupply() * 80 / 100;
  }

  event FaceWorthPollDeployed (
    address indexed contractAddress,
    address indexed initiator,
    bytes32 faceHash,
    uint startingBlock,
    uint commitEndingBlock,
    uint revealEndingBlock
  );

  function deployFaceWorthPoll(
    bytes32 _faceHash,
    uint _blocksBeforeReveal,
    uint _blocksBeforeEnd,
    uint _participantsRequired
  )
    public
    returns (address contractAddress)
  {
    require(_blocksBeforeReveal >= minBlocksBeforeReveal);
    require(_blocksBeforeEnd >= minBlocksBeforeEnd);
    require(_participantsRequired >= minParticipants && _participantsRequired <= maxParticipants);
    FaceToken faceToken = FaceToken(faceTokenAddress);
    contractAddress = new FaceWorthPoll(
        address(this),
        faceToken.decimals(),
        msg.sender,
        _faceHash,
        _blocksBeforeReveal,
        _blocksBeforeEnd,
        _participantsRequired,
        stake,
        winnersPerThousand,
        distPercentage
    );
    deployed[contractAddress] = true;
    deployedPolls.push(contractAddress);
    FaceWorthPoll faceWorthPoll = FaceWorthPoll(contractAddress);
    emit FaceWorthPollDeployed(
      contractAddress,
      faceWorthPoll.initiator(),
      faceWorthPoll.faceHash(),
      faceWorthPoll.startingBlock(),
      faceWorthPoll.commitEndingBlock(),
      faceWorthPoll.revealEndingBlock()
    );
  }

  function rewardFaceTokens(address _receiver, uint _value) external {
    require(deployed[msg.sender]);
    FaceToken faceToken = FaceToken(faceTokenAddress);
    faceToken.increaseApproval(_receiver, _value);
    faceTokenRewardPool = faceTokenRewardPool.sub(_value);
  }

  function getNumberOfPolls() public view returns (uint n_) {
    n_ = deployedPolls.length;
  }

  function verify(address contractAddress) public view returns (
    bool valid,
    address initiator,
    bytes32 faceHash,
    uint startingBlock,
    uint commitEndingBlock,
    uint revealEndingBlock
  ) {
    valid = deployed[contractAddress];
    if (valid) {
      FaceWorthPoll poll = FaceWorthPoll(contractAddress);
      initiator = poll.initiator();
      faceHash = poll.faceHash();
      startingBlock = poll.startingBlock();
      commitEndingBlock = poll.commitEndingBlock();
      revealEndingBlock = poll.revealEndingBlock();
    }
  }

  function updateStake(uint _stake) external onlyOwner {
    require(_stake != stake);
    uint oldStake = stake;
    stake = _stake;
    emit StakeUpdate(stake, oldStake);
  }

  function updateParticipantsRange(uint _minParticipants, uint _maxParticipants) external onlyOwner {
    require(_minParticipants <= _maxParticipants);
    require(_minParticipants != minParticipants || _maxParticipants != maxParticipants);
    if (_minParticipants != minParticipants) {
      uint oldMinParticipants = minParticipants;
      minParticipants = _minParticipants;
      emit MinParticipantsUpdate(minParticipants, oldMinParticipants);
    }
    if (_maxParticipants != maxParticipants) {
      uint oldMaxParticipants = maxParticipants;
      maxParticipants = _maxParticipants;
      emit MaxParticipantsUpdate(maxParticipants, oldMaxParticipants);
    }
  }

  function updateRewardRatios(uint _winnersPerThousand, uint _distPercentage) external onlyOwner {
    require(_distPercentage <= 100);
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

  function updateMinBlocksBeforeReveal(uint _minBlocksBeforeReveal) external onlyOwner {
    require(_minBlocksBeforeReveal != minBlocksBeforeReveal);
    uint oldMinBlocksBeforeReveal = minBlocksBeforeReveal;
    minBlocksBeforeReveal = _minBlocksBeforeReveal;
    emit MinBlocksBeforeRevealUpdate(minBlocksBeforeReveal, oldMinBlocksBeforeReveal);
  }

  function updateMinBlocksBeforeEnd(uint _minBlocksBeforeEnd) external onlyOwner {
    require(_minBlocksBeforeEnd != minBlocksBeforeEnd);
    uint oldMinBlocksBeforeEnd = minBlocksBeforeEnd;
    minBlocksBeforeEnd = _minBlocksBeforeEnd;
    emit MinBlocksBeforeEndUpdate(minBlocksBeforeEnd, oldMinBlocksBeforeEnd);
  }

  function() public payable {
    revert();
  }

  event StakeUpdate(uint newStake, uint oldStake);

  event MinParticipantsUpdate(uint newMinParticipants, uint oldMinParticipants);

  event MaxParticipantsUpdate(uint newMaxParticipants, uint oldMaxParticipants);

  event RewardRatiosUpdate(uint newWinnersPerThousand, uint oldWinnersPerThousand);

  event DistPercentageUpdate(uint newDistPercentage, uint oldDistPercentage);

  event MinBlocksBeforeRevealUpdate(uint newMinBlocksBeforeReveal, uint oldMinBlocksBeforeReveal);

  event MinBlocksBeforeEndUpdate(uint newMinBlocksBeforeUpdate, uint oldMinBlocksBeforeUpdate);
}