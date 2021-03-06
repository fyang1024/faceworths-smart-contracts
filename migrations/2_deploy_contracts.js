const FaceToken = artifacts.require("../Contract/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

module.exports = function(deployer) {
    deployer.deploy(FaceToken).then (function() {
        console.log("FaceToken.address", FaceToken.address);
        deployer.deploy(FaceWorthPollFactory, FaceToken.address).then (function() {
            console.log("FaceWorthPollFactory.address", FaceWorthPollFactory.address);
        });
    });
}