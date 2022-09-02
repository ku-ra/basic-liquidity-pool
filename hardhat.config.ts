import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

require('dotenv').config;

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/" + process.env.ALCHEMY_GOERLI_KEY
    }
  }
};

export default config;
