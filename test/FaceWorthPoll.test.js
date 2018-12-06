const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPoll = artifacts.require("../contracts/FaceWorthPoll.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");
const keccak256 = require("js-sha3").keccak256;

contract('FaceWorthPollFactory', async (accounts) => {

  let faceToken;
  let factory;

  beforeEach(async () => {
    faceToken = await FaceToken.deployed();
    factory = await FaceWorthPollFactory.new(faceToken.address);
  });

  it("faceTokenRewardPool is 80 percent of FaceToken totalSupply", async () => {
    let totalSupplyInSun = await faceToken.totalSupply();
    let decimals = await faceToken.decimals();
    let totalSupply = totalSupplyInSun / (10 ** decimals);
    let eightyPercentOfTotalSupply = totalSupply * 8 / 10;
    let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool();
    let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
    assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 80 percent of FaceToken totalSupply");
  });

  it("FaceWorthPoll contract is created successfully", async () => {
    let faceHash = '0x' + keccak256("Some face photo");
    let blocksBeforeReveal = 10; // min number of blocks
    let blocksBeforeEnd = blocksBeforeReveal;
    let participantsRequired = 3;
    await factory.deployFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd, participantsRequired);
    let numberOfPolls = await factory.getNumberOfPolls();
    assert.equal(numberOfPolls, 1, "Number of polls wasn't 1 after 1 poll is created");
    let event = factory.FaceWorthPollDeployed();
    event.watch(async (err, response) => {
      let result = await factory.verify(response.args.contractAddress);
      assert.equal(result[0], true, "The result wasn't valid");
      assert.equal(result[1], accounts[0], "Initiator wasn't set correctly");

      let poll = await FaceWorthPoll.at(response.args.contractAddress);

      let stake = await factory.stake();
      let score = [1, 2, 2, 3, 3, 3, 3, 3, 3, 4];
      for (let i = 0; i < accounts.length; i++) {
        let saltedWorthHash = '0x' + keccak256("中文-" + score[i]);
        await poll.commit(saltedWorthHash, {from: accounts[i], value: stake});
      }

      await poll.checkBlockNumber();

      for (let i = 0; i < accounts.length; i++) {
        await poll.reveal("中文-", score[i], {from: accounts[i]});
      }

      await poll.checkBlockNumber();

      let winners = await poll.getWinners();
      for (let i = 0; i < winners.length; i++) {
        let worth = await poll.getWorthBy(winners[i]);
        console.log(winners[i], worth);
      }

      let approvalEvent = faceToken.Approval();
      let approvalCount = 0;
      let loserCount = accounts.length - winners.length;
      approvalEvent.watch((err, response) => {
        approvalCount++;
        console.log("Approval", response.args);
        if (approvalCount === loserCount) {
          approvalEvent.stopWatching();
        }
      });
      event.stopWatching();
    });
  })
});