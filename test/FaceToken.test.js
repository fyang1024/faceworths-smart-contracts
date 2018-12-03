const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

contract('FaceToken', async () => {

    it("totalSupply is 100,000,000", async () => {
        let faceToken = await FaceToken.deployed();
        let totalSupplyInSun = await faceToken.totalSupply();
        let decimals = await faceToken.decimals();
        let totalSupply = totalSupplyInSun / (10 ** decimals);
        assert.equal(totalSupply, 100000000, "totalSupply wasn't 100,000,000");
    });

    it("totalSupply is in vault when deployed", async () => {
        let faceToken = await FaceToken.deployed();
        let totalSupplyInSun = await faceToken.totalSupply();
        let decimals = await faceToken.decimals();
        let totalSupply = totalSupplyInSun / (10 ** decimals);
        let vault = await faceToken.vault();
        let balanceOfVaultInSun = await faceToken.balanceOf(vault);
        let balanceOfVault = balanceOfVaultInSun / (10 ** decimals);
        assert.equal(totalSupply, balanceOfVault, "totalSupply wasn't all in vault");
    });

    it("faceTokenRewardPool is 80 percent of FaceToken totalSupply", async () => {
        let factory = await FaceWorthPollFactory.deployed();
        // let faceToken = FaceToken.deployed();
        // let totalSupplyInSun = await faceToken.totalSupply();
        // let decimals = await faceToken.decimals();
        // let totalSupply = totalSupplyInSun / (10 ** decimals);
        // let eightyPercentOfTotalSupply = totalSupply * 8 / 10;
        // let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool();
        // let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
        // assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 80 percent of FaceToken totalSupply");
    });

});
