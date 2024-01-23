import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

import "dotenv/config";

if (!process.env.TESTNET_PRIVATE_KEY) {
  throw new Error("Please set your private key in a .env file");
}

if (!process.env.TESTNET_BSCERSCAN_API_KEY) {
  throw new Error("Please set your BscScan API key in a .env file");
}

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    tbsc: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      accounts: [process.env.TESTNET_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.TESTNET_BSCERSCAN_API_KEY,
  },
};

export default config;
