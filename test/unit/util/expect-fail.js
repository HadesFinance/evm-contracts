const BlockchainCaller = require('./blockchain-caller')
const chain = new BlockchainCaller(web3)

async function expectFail(transaction) {
    expect(
        await chain.isEthException(transaction)
      ).to.be.true;
}

module.exports = expectFail