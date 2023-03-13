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
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 0,
          },
        },
      },
      // {
      //   version: "0.6.12",
      // },
    ],

  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      // blockGasLimit: 2578162, 
      forking: {
        enabled: process.env.FORKING_ENABLED == "true",
        url: process.env.FORKING_URL as string,
        blockNumber: 57393222,
      }
    },
    // fantom: {
    //   url: process.env.FANTOM_URL,
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
    // TESTNETS
    fantom_testnet: {
      url: process.env.FANTOM_TESTNET_URL,
      accounts: [process.env.PRIVATE_KEY as string],
      // accounts: {
      //   mnemonic: process.env.MNEMONIC,
      // },
    },
    mumbai: {
      url: process.env.MUMBAI_URL,
      accounts: [process.env.PRIVATE_KEY as string],
      // accounts: {
      //   mnemonic: process.env.MNEMONIC,
      // },
    },
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS == "true",
    currency: "USD",
  },
  // etherscan: {
  //   // apiKey: process.env.ETHERSCAN_API_KEY,
  //   apiKey: process.env.POLYGONSCAN_API_KEY,

  // },

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
