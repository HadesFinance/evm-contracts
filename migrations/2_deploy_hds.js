const HDS = artifacts.require("HDS");

module.exports = function (deployer) {
    deployer.then(async () => {
        await deployer.deploy(HDS);
        console.log('HDS address:', HDS.address);
    })
}