const HDWalletProvider = require('truffle-hdwallet-provider')
const env = require('./.env.js')

module.exports = {
  contracts_directory: "./src",
  compilers: {
    solc: {
      version: "0.6.0",
    }
  },
  networks: {
    develop: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      gas: 100000000,
    },
    ropsten: {
      provider: function() {
        return new HDWalletProvider([env.ropsten.privateKey], env.ropsten.provider)
      },
      network_id: 3,
      gas: 4000000,
    },
    live: {
      provider: function() {
        return new HDWalletProvider([env.live.privateKey], env.live.provider)
      },
      network_id: 1,
      gas: 4000000,
    },
  }
};