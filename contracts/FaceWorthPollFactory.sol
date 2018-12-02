pragma solidity ^0.4.24;

import "./Owned.sol";
import "./FaceWorthPoll.sol";
import "./FaceToken.sol";

contract FaceWorthPollFactory is Owned {

  uint public stake = 100000000; // every participant stake 100 trx
  uint public minParticipants = 3;
  uint public maxParticipants = 10000;
  uint public winnersReturn = 3;   // winnersReturn * distPercentage must be greater than 100,
  uint public distPercentage = 90; // so that winners prize is greater than the stake
  uint public minBlocksBeforeReveal = 100; // 100 blocks is about 300 seconds or 5 minutes
  uint public minBlocksBeforeEnd = 100;

  // TODO !!IMPORTANT!! UPDATE THE ADDRESS ONCE THE FACETOKEN CONTRACT IS DEPLOYED
  address public constant faceTokenAddress = 0x0;

  mapping(address => bool) deployed;

  address[] deployedPolls;

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
        winnersReturn,
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

  function updateReturnPercentage(uint _winnersReturn, uint _distPercentage) external onlyOwner {
    require(_distPercentage <= 100);
    require(_winnersReturn * _distPercentage > 100);
    require(_winnersReturn != winnersReturn || _distPercentage != distPercentage);
    if (_winnersReturn != winnersReturn) {
      uint oldWinnersReturn = winnersReturn;
      winnersReturn = _winnersReturn;
      emit WinnersReturnUpdate(winnersReturn, oldWinnersReturn);
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

  event WinnersReturnUpdate(uint newWinnersReturn, uint oldWinnersReturn);

  event DistPercentageUpdate(uint newDistPercentage, uint oldDistPercentage);

  event MinBlocksBeforeRevealUpdate(uint newMinBlocksBeforeReveal, uint oldMinBlocksBeforeReveal);

  event MinBlocksBeforeEndUpdate(uint newMinBlocksBeforeUpdate, uint oldMinBlocksBeforeUpdate);
}