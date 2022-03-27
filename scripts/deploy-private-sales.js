// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  // Codes below are set to deploy on testnet
  const Contract = await hre.ethers.getContractFactory("CHROPrivateSales");
  const contract = await Contract.deploy("0xbf1230bb63bfD7F5D628AB7B543Bcefa8a24B81B", "0xb97ef9ef8734c71904d8002f8b6bc66dd9c48a6e", "0xffb1160d6655cAc11F771CbB34104F7a2321Fe77");

  await contract.deployed();

  console.log("CHROPrivateSales deployed to:", contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});