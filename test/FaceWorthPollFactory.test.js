const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");
const Tronweb = require("tronweb");

contract('FaceWorthPollFactory', async (accounts) => {

    let faceToken;
    let factory;

    beforeEach(async () => {
        faceToken = await FaceToken.deployed();
        factory = await FaceWorthPollFactory.new(faceToken.address)
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
        let faceHash = Tronweb.sha3("Some face photo", true);
        let blocksBeforeReveal = 100; // min number of blocks
        let blocksBeforeEnd = blocksBeforeReveal;
        let participantsRequired = 3;
        await factory.deployFaceWorthPoll(faceHash, blocksBeforeReveal, blocksBeforeEnd, participantsRequired);
        let numberOfPolls = await factory.getNumberOfPolls();
        assert.equal(numberOfPolls, 1, "Number of polls wasn't 1 after 1 poll is created");
        let event = factory.FaceWorthPollDeployed();
        event.watch( async (err, response) => {
            let result = await factory.verify(response.args.contractAddress);
            assert.equal(result[0], true, "The result wasn't valid");
            assert.equal(result[1], accounts[0], "Initiator wasn't set correctly");
            event.stopWatching();
        });
    })
});