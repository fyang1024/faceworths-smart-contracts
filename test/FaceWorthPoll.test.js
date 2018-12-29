const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");
const keccak256 = require("js-sha3").keccak256;

contract('FaceWorthPollFactory', async (accounts) => {

  let faceToken;
  let factory;

  beforeEach(async () => {
    faceToken = await FaceToken.deployed();
    factory = await FaceWorthPollFactory.new(faceToken.address);
  });

  it("faceTokenRewardPool is 61.8 percent of FaceToken totalSupply", async () => {
    let totalSupplyInWei = await faceToken.totalSupply();
    let decimals = await faceToken.decimals();
    let totalSupply = totalSupplyInWei / (10 ** decimals);
    let portionOfTotalSupply = totalSupply * 618 / 1000;
    let faceTokenRewardPoolInWei = await factory.faceTokenRewardPool();
    let faceTokenRewardPool = faceTokenRewardPoolInWei / (10 ** decimals);
    console.log("faceTokenRewardPool", faceTokenRewardPool);
    assert.equal(portionOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 61.8 percent of FaceToken totalSupply");
  });

  it("FaceWorthPoll is created successfully", async () => {
    let faceHash = '0x' + keccak256("Some face photo");
    let blocksBeforeReveal = 10; // min number of blocks
    let blocksBeforeEnd = 10;
    await factory.createFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd);
    let pollCount = await factory.getPollCount();
    assert.equal(pollCount, 1, "Poll count wasn't 1 after 1 poll is created");

    let approvalEvent = faceToken.Approval();
    approvalEvent.watch((err, response) => {
      console.log("Approval", response.args);
    });

    let stageChangeEvent = factory.StageChange();
    stageChangeEvent.watch((err, response) => {
      console.log('Stage Change', response.args);
    });

    let creationEvent = factory.FaceWorthPollCreated();
    creationEvent.watch(async (err, response) => {
      assert.equal(response.args.creator, accounts[0], "Creator wasn't set correctly");
      let hash = response.args.hash;
      let stake = await factory.stake();
      let score = [15, 9, 8, 6, 6, 6, 4, 3, 2, 1];
      for (let i = 0; i < accounts.length; i++) {
        let saltedWorthHash = '0x' + keccak256("中文-" + score[i]);
        await factory.commit(hash, saltedWorthHash, {from: accounts[i], value: stake});
      }

      await factory.checkBlockNumber(hash);

      for (let i = 0; i < accounts.length; i++) {
        await factory.reveal(hash, "中文-", score[i], {from: accounts[i]});
      }

      await factory.checkBlockNumber(hash);

      let winners = await factory.getWinners(hash);
      for (let i = 0; i < winners.length; i++) {
        let worth = await factory.getWorthBy(hash, winners[i]);
        console.log(winners[i], worth);
      }

      creationEvent.stopWatching();
    });
  })
});