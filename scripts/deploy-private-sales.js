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
  const contract = await Contract.deploy("0xb240B43ec9564d57dd8B33Ee88ff618e86CcCB1A", "0x7D52b181F444A909A643D8AB3CC83041b8018921");

  await contract.deployed();

  console.log("CHROPrivateSales deployed to:", contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});