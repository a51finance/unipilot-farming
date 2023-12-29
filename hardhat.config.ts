import fs from "fs";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import { HardhatUserConfig, task } from "hardhat/config";
require("@nomicfoundation/hardhat-foundry");
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "solidity-coverage";

import "./tasks/accounts";

import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { NetworkUserConfig } from "hardhat/types";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const chainIds = {
  ganache: 1337,
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
  mumbai: 80001,
  polygon: 137,
  optgoerli: 420,
  arbgoerli: 421613,
  optimism: 10,
  zkevm: 1101,
  dogechain: 2000,
};

// Ensure that we have all the environment variables we need.
const mnemonic = process.env.MNEMONIC;
if (!mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

const infuraApiKey = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error("Please set your INFURA_API_KEY in a .env file");
}

let alchemyapiKey = process.env.FORK;

const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
// const zkevmApiKey = process.env.ZKEVM_API_KEY || "";

function createTestnetConfig(
  network: keyof typeof chainIds
): NetworkUserConfig {
  const url: string =
    network == "mumbai"
      ? "https://polygon-mumbai.g.alchemy.com/v2/0zYR0X60apvZglZAMDnA7dHmE7lG4amL"
      : // : "https://polygon-mainnet.g.alchemy.com/v2/g2JAXug5sBd7l8VuSlEYvUB3PysaxSFx";
        // "https://rpc.ankr.com/dogechain";
        // "https://zkevm-rpc.com";
        "https://eth.llamarpc.com";
  // "https://ethereum-goerli.publicnode.com";
  // : "https://polygon-mainnet.g.alchemy.com/v2/g2JAXug5sBd7l8VuSlEYvUB3PysaxSFx";
  return {
    accounts: [`${process.env.PKEY}`, `${process.env.PKEY}`],
    chainId: chainIds[network],
    url,
  };
}
const coinMarketCapKey = process.env.COIN_MARKETCAP;

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",

  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        //mnemonic,
      },
      chainId: chainIds.hardhat,
    },

    goerli: createTestnetConfig("goerli"),
    kovan: createTestnetConfig("kovan"),
    rinkeby: createTestnetConfig("rinkeby"),
    ropsten: createTestnetConfig("ropsten"),
    mainnet: createTestnetConfig("mainnet"),
    mumbai: createTestnetConfig("mumbai"),
    polygon: createTestnetConfig("polygon"),
    optgoerli: createTestnetConfig("optgoerli"),
    arbgoerli: createTestnetConfig("arbgoerli"),
    optimism: createTestnetConfig("optimism"),
    zkevm: createTestnetConfig("zkevm"),
    dogechain: createTestnetConfig("dogechain"),
  },
  mocha: {
    timeout: 50000,
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./src",
    tests: "./test",
  },
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          metadata: {
            // Not including the metadata hash
            // https://github.com/paulrberg/solidity-template/issues/31
            bytecodeHash: "none",
          },
          // You should disable the optimizer when debugging
          // https://hardhat.org/hardhat-network/#solidity-optimizer-support
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
    ],
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5",
  },
  etherscan: {
    apiKey: {
      goerli: "GSWUYPSZGBKJ168A2M78TF7VUA97AP6G22",
      mainnet: "GSWUYPSZGBKJ168A2M78TF7VUA97AP6G22",
      polygon: "U454CGF88K6BJYPTMYP447Q2VFUMT6QHZ9",
      polygonMumbai: "U454CGF88K6BJYPTMYP447Q2VFUMT6QHZ9",
      zkevm: "2RQMY1GRQD38KP8DQX8KEP9DDEFKVK38HJ",
      dogechain: "B9YRT6VCBUX8IWEARQQPW5C4VX89ISEXFC",
    },
    customChains: [
      {
        network: "zkevm",
        chainId: 1101,
        urls: {
          apiURL: "https://api-zkevm.polygonscan.com/api",
          browserURL: "https://zkevm.polygonscan.com/",
        },
      },
      {
        network: "dogechain",
        chainId: 2000,
        urls: {
          apiURL: "https://explorer.dogechain.dog/api",
          browserURL: "https://explorer.dogechain.dog/",
        },
      },
    ],
  },
};

export default config;
