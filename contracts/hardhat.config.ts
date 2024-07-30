import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "@nomicfoundation/hardhat-verify";
import { ethers } from "ethers";
import { accounts } from './config/account.js'
import { CHAIN_CONFIG } from './config/chain.js';
import dotenv from 'dotenv'
dotenv.config()

if ((accounts as any).mnemonic) {
    let mnemonicWallet = ethers.Wallet.fromMnemonic((accounts as any).mnemonic);
    // console.log('Test account used from MNEMONIC', mnemonicWallet.privateKey, mnemonicWallet.address);
} else {
    let wallet = new ethers.Wallet(accounts[0]);
    // console.log('Test account used from TEST_ACCOUNT_PRIVATE_KEY', wallet.address);
}

const chains = Object.keys(CHAIN_CONFIG);
const networks = {};
chains.forEach(chain => {
  networks[chain] = {
    ...CHAIN_CONFIG[chain],
    accounts,
    mining: {
      auto: false,
      interval: 3000
    }
  }
});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  } as any,
  networks: {
    hardhat: {
      accounts,
    },
    local: {
      url: 'http://127.0.0.1:8545',
      accounts,
    },
    ...networks,
    localhost1: {
      url: 'http://localhost:8545',
    },
    localhost2: {
      url: 'http://localhost:8546',
    },
    arbitrumOne: {
      url: 'https://nd-829-997-700.p2pify.com/790712c620e64556719c7c9f19ef56e3',
      accounts: [process.env.DEPLOYER_KEY!]
    },
    base: {
      url: 'https://base-mainnet.core.chainstack.com/e7aa01c976c532ebf8e2480a27f18278',
      accounts: [process.env.DEPLOYER_KEY!]
    },
  } as any,
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ARBISCAN_API_KEY!,
      base: process.env.BASESCAN_API_KEY!,
    }
  },
};
