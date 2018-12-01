pragma solidity ^0.4.24;

import "./Owned.sol";
import "./FaceWorthPoll.sol";
import "./FaceToken.sol";

contract FaceWorthPollFactory is Owned {

  // TODO !!IMPORTANT!! UPDATE THE ADDRESS ONCE THE FACETOKEN CONTRACT IS DEPLOYED
  address public constant faceTokenAddress = 0x0;

  mapping(address=>bool) deployed;

  address[] deployedPolls;

  event FaceWorthPollDeployed (
    address indexed initiator,
    bytes32 faceHash,
    uint startingBlock,
    uint endingBlock
  );


  function deployFaceWorthPoll(bytes32 _faceHash, uint _endingBlock, uint _participantsRequired)
    public
    returns (address contractAddress)
  {
    contractAddress = new FaceWorthPoll(msg.sender, _faceHash, _endingBlock, _participantsRequired);
    deployed[contractAddress] = true;
    deployedPolls.push(contractAddress);
    FaceWorthPoll faceWorthPoll = FaceWorthPoll(contractAddress);
    emit FaceWorthPollDeployed(
        faceWorthPoll.initiator(),
        faceWorthPoll.faceHash(),
        faceWorthPoll.startingBlock(),
        faceWorthPoll.endingBlock()
    );
    FaceToken faceToken = FaceToken(faceTokenAddress);
    if(faceToken.allowance(faceToken.initialVault(), address(this)) > 0) {
      // pay 1 FACE token once user starts a new game
      faceToken.transferFrom(faceToken.initialVault(), faceWorthPoll.initiator(), 10**faceToken.decimals());
    }
  }

  function getNumberOfPolls() public view returns (uint n_) {
    n_ = deployedPolls.length;
  }

  function verify(address contractAddress) public view returns (
    bool    valid,
    address initiator,
    bytes32 faceHash,
    uint    startingBlock,
    uint    endingBlock
  ) {
    valid = deployed[contractAddress];
    if (valid) {
      FaceWorthPoll poll = FaceWorthPoll(contractAddress);
      initiator  = poll.initiator();
      faceHash = poll.faceHash();
      startingBlock = poll.startingBlock();
      endingBlock = poll.endingBlock();
    }
  }

  function () public payable {
    revert();
  }
}
