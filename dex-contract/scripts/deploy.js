const { ethers } = require("hardhat");
require("dotenv").config({ path: ".env" });
const { ANTIPARALLEL_TOKEN_CONTRACT_ADDRESS } = require("../constants");

async function main() {
  const antiparallelTokenAddress = ANTIPARALLEL_TOKEN_CONTRACT_ADDRESS;
  /*
  A ContractFactory in ethers.js is an abstraction used to deploy new smart contracts,
  so exchangeContract here is a factory for instances of the Exchange contract.
  */
  const exchangeContract = await ethers.getContractFactory("Exchange");

  // deploy the contract
  const deployedExchangeContract = await exchangeContract.deploy(
    antiparallelTokenAddress
  );
  await deployedExchangeContract.deployed();

  // print address of deployed contract
  console.log("Exchange Contract Address:", deployedExchangeContract.address);
}

// Call the main function and catch if there is any error
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });