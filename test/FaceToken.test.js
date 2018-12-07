const FaceToken = artifacts.require("../contracts/FaceToken.sol");

contract('FaceToken', async () => {

    let faceToken;

    beforeEach(async () => {
        faceToken = await FaceToken.deployed();
    });

    it("totalSupply is 100,000,000", async () => {
        let totalSupplyInSun = await faceToken.totalSupply();
        let decimals = await faceToken.decimals();
        let totalSupply = totalSupplyInSun / (10 ** decimals);
        assert.equal(totalSupply, 1000000000, "totalSupply wasn't 1,000,000,000");
    });

    it("totalSupply is in vault when deployed", async () => {
        let totalSupplyInSun = await faceToken.totalSupply();
        let decimals = await faceToken.decimals();
        let totalSupply = totalSupplyInSun / (10 ** decimals);
        let vault = await faceToken.vault();
        let balanceOfVaultInSun = await faceToken.balanceOf(vault);
        let balanceOfVault = balanceOfVaultInSun / (10 ** decimals);
        assert.equal(totalSupply, balanceOfVault, "totalSupply wasn't all in vault");
    });
});
