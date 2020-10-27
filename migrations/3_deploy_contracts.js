const SafeMath = artifacts.require("SafeMath");
const Strings = artifacts.require("Strings");
const Address = artifacts.require("Address");

const DOL = artifacts.require("DOL");
const MockPriceOracle = artifacts.require("MockPriceOracle");
const DefaultInterestRateStrategy = artifacts.require("DefaultInterestRateStrategy");
const MarketController = artifacts.require("MarketController");
const HDSDistributor = artifacts.require("HDSDistributor");
const Timelock = artifacts.require("Timelock");
const Governance = artifacts.require("Governance");
const ProtocolReporter = artifacts.require("ProtocolReporter");
const HEther = artifacts.require("HEther");
const HErc20 = artifacts.require("HErc20");

const Orchestrator = artifacts.require("Orchestrator");

module.exports = function (deployer) {
//   deployer.then(async () => {
//     const contracts = [
//       DOL, MockPriceOracle, DefaultInterestRateStrategy, MarketController, HDSDistributor, Timelock, Governance, ProtocolReporter
//     ]
//     for (let c of contracts) {
//       await deployer.deploy(c)
//     }

//     const addresses = contracts.map(c => c.address);
//     console.log('addresses:', addresses);

//     await deployer.deploy(HEther);
//     await deployer.deploy(HErc20);
//     console.log('HEther:', HEther.address);
//     console.log('HErc20:', HErc20.address);

//     await deployer.deploy(Orchestrator);
//     console.log("Orchestrator:", Orchestrator.address)
//   })
};