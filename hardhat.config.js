require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@tenderly/hardhat-tenderly");
require("@nomiclabs/hardhat-ethers");
// require("hardhat-gas-reporter");
require('hardhat-log-remover');
require("solidity-coverage");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    local: {
			url: 'http://127.0.0.1:8546'
	  },
    hardhat: {
      forking: {
        url: process.env.ALCHEMY_NODE,
       //  blockNumber: 12068716
      }
    },
    mainnet: {
        url: process.env.ALCHEMY_NODE,
        accounts: [process.env.PRIV_KEY_MAINNET],
        gasPrice: 40000000000
    },
    frontend_fork: {
      url: process.env.FRONTEND_FORK_URL,
      accounts: [process.env.PRIV_KEY_FRONTEND_FORK]
    }
  },
  solidity: "0.7.6",
  settings: {
    optimizer: {
      enabled: false,
      runs: 1000
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
},
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  tenderly: {
    username: process.env.TENDERLY_USERNAME,
    project: process.env.TENDERLY_PROJECT,
    forkNetwork: "1"
  },
  mocha: {
    timeout: 60000
  }
};
