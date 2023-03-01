import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
// import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import 'hardhat-contract-sizer'
// import './tasks'
import '@openzeppelin/hardhat-upgrades';

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 0,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        enabled: process.env.FORKING_ENABLED == "true",
        url: process.env.FORKING_URL as string,
       // blockNumber: 14785940
      }
    },
    // fantom: {
    //   url: process.env.FANTOM_URL,
    //   gasPrice: "auto",
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC,
    //   },
    // },
    fantom_testnet: {
      url: process.env.FANTOM_TESTNET_URL,
      gasPrice: "auto",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
    },

    // mainnet: {
    //   url: process.env.MAINNET_URL,
    //   gasPrice: 8000000000,
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC,
    //   },
    // },
    // polygon: {
    //   url: process.env.POLYGON_URL,
    //   gasPrice: "auto",
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC,
    //   },
    // },
    // // TESTNETS
    // mumbai: {
    //   url: process.env.MUMBAI_URL,
    //   gasPrice: "auto",
    //   accounts: {
    //     mnemonic: process.env.MNEMONIC,
    //   },
    // },
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS == "true",
    currency: "USD",
  },
  etherscan: {
    // apiKey: process.env.ETHERSCAN_API_KEY,
    apiKey: process.env.POLYGONSCAN_API_KEY,

  },

  mocha: {
    timeout: 3600000,
  },
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: process.env.CONTRACT_SIZER == "true",
    strict: false,
  }
};

export default config;
