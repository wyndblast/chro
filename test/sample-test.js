const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

let Contract;
let contract;
let VestingContract;
let vestingContract;
let PrivateSalesContract;
let privateSalesContract;

describe("CHRO", function () {
  /*
  before(async function () {
    [ownerOne, ownerTwo, ownerThree, ownerFour] = await ethers.getSigners();
    
    // CHRO contract
    Contract = await ethers.getContractFactory("CHRO");
    contract = await Contract.deploy();
    await contract.deployed();

    // Private Sales contract
    PrivateSalesContract = await ethers.getContractFactory("CHROPrivateSales");
    privateSalesContract = await PrivateSalesContract.deploy(contract.address);
    await privateSalesContract.deployed();
    console.log(privateSalesContract.address);
  });

  describe("Deployment", function () {
    it('Mint 15,000,000 to Private Sales Contract', async function () {
      await contract.connect(ownerOne).mint(privateSalesContract.address, ethers.utils.parseEther("15000000"))

      const balanceOf = await contract.balanceOf(privateSalesContract.address);
      expect(ethers.utils.formatEther(balanceOf)).to.equal("15000000.0");
    });

    it("Balance of Private Sales is 15,000,000", async function () {
      const balanceOf = await contract.totalSupply();
      expect(ethers.utils.formatEther(balanceOf)).to.equal("15000000.0");
      assert.isOk(ethers.utils.formatEther(balanceOf))
    });

    it("Total supply is 15,000,000", async function () {
      const balanceOf = await contract.totalSupply();
      expect(ethers.utils.formatEther(balanceOf)).to.equal("15000000.0");
      assert.isOk(ethers.utils.formatEther(balanceOf))
    });
  });
  
  describe("Pausable Test", function () {
    it("Test pause", async function () {
      await contract.connect(ownerOne).pause()
      const isPaused = await contract.paused()
      expect(isPaused).to.equal(true)
    });

    it("Test unpause", async function () {
      await contract.connect(ownerOne).unpause();
      const isPaused = await contract.paused();

      if (!isPaused) {
        await contract.connect(ownerOne).transfer("0x70997970C51812dc3A010C7d01b50e0d17dc79C8", ethers.utils.parseEther("100"))
      }
    });

    it("Balance of 0x709979...7dc79C8 should be 100 CHRO", async function () {
      const balance = await contract.balanceOf("0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
      expect(ethers.utils.formatEther(balance)).to.equal("100.0")
    });
  });
  */
});