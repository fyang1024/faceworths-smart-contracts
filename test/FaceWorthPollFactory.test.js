const FaceToken = artifacts.require("../contracts/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

// contract('FaceWorthPollFactory', async () => {
//
//     it("faceTokenRewardPool is 80 percent of FaceToken totalSupply", async () => {
//         let factory = await FaceWorthPollFactory.deployed();
//         let faceToken = FaceToken.deployed();
//         let totalSupplyInSun = await faceToken.totalSupply();
//         let decimals = await faceToken.decimals();
//         let totalSupply = totalSupplyInSun / (10 ** decimals);
//         let eightyPercentOfTotalSupply = totalSupply * 8 / 10;
//         let faceTokenRewardPoolInSun = await factory.faceTokenRewardPool();
//         let faceTokenRewardPool = faceTokenRewardPoolInSun / (10 ** decimals);
//         assert.equal(eightyPercentOfTotalSupply, faceTokenRewardPool, "faceTokenRewardPool wasn't 80 percent of FaceToken totalSupply");
//     });
// });