const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

let Contract;
let contract;
let VestingContract;
let vestingContract;
let PrivateSalesContract;
let privateSalesContract;

describe("WBMultiSigWallet", function () {
  before(async function () {
    [ownerOne, ownerTwo, ownerThree, ownerFour] = await ethers.getSigners();
    
    // CHRO contract
    Contract = await ethers.getContractFactory("WBMultiSigWallet");
    contract = await Contract.deploy();
    await contract.deployed();
    //console.log(contract.address);
  });

  describe("Deployment", function () {
    it.only('Deployer address is 0xf39F...92266', async function () {
      const deployer = await contract.getDeployer()
      expect(deployer).to.equal("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
    });

    it.only('Deployer add new wallet', async function () {
      await contract.connect(ownerOne).addWallet("0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E", "USDC", "USD Coin (USDC)", ethers.utils.parseEther("25000"))
      const wallet = await contract.wallets(1)
      expect(wallet.name).to.equal("USDC")
    });

    it.only('Transfer 10 ether to contract', async function () {
      await ownerTwo.sendTransaction({
        to: contract.address,
        value: ethers.utils.parseEther("5")
      })
      
      const balance = await contract.getBalance(0)
      expect(balance).to.equal(ethers.utils.parseEther("5"))
    });

    it.only('Set limit wallet 1 (USDC) to 30,000', async function () {
      await contract.connect(ownerOne).changeDailyLimit(0, ethers.utils.parseEther("30000"))
      const wallet = await contract.wallets(0)
      expect(wallet.dailyLimit).to.equal(ethers.utils.parseEther("30000"))
    });

    it.only('Add owners', async function () {
      await contract.connect(ownerOne).addOwner("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
      await contract.connect(ownerOne).addOwner("0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC")
      const owners = await contract.getOwners()
      expect(owners[1]).to.equal("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")
    });

    it.only("Init transactions from wallet 0", async function () {
      await contract.connect(ownerOne).submitTransaction(0, ownerFour.address, ethers.utils.parseEther("2"), ethers.utils.formatBytes32String("Test transfer 1"))
      await contract.connect(ownerOne).submitTransaction(0, ownerFour.address, ethers.utils.parseEther("3"), ethers.utils.formatBytes32String("Test transfer 2"))
      await contract.connect(ownerOne).submitTransaction(0, ownerFour.address, ethers.utils.parseEther("4"), ethers.utils.formatBytes32String("Test transfer 3"))
      const transaction = await contract.getTransaction(0, 0)
      expect(transaction.value).to.equal(ethers.utils.parseEther("2"))
    });

    it.only("Get wallets", async function () {
      const wallets = await contract.getWallets()
      console.log(wallets)
      // expect(wallets).to.equal(ethers.utils.parseEther("2"))
    });

    it.only("Get transactions", async function () {
      const transactions = await contract.getTransactions(0)
      console.log(transactions)
      // expect(wallets).to.equal(ethers.utils.parseEther("2"))
    });
  });
});