const FaceToken = artifacts.require("../Contract/FaceToken.sol");
const FaceWorthPollFactory = artifacts.require("../contracts/FaceWorthPollFactory.sol");

module.exports = function(deployer) {
    deployer.deploy(FaceToken, 0x88884e35d7006AE84EfEf09ee6BC6A43DD8E2BB8).then (function() {
        console.log("FaceToken.address", FaceToken.address);
        deployer.deploy(FaceWorthPollFactory, FaceToken.address).then (function() {
            console.log("FaceWorthPollFactory.address", FaceWorthPollFactory.address);
        });
    });
}