const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

let Contract;
let contract;

describe("CHRO", function () {
  before(async function () {
    Contract = await ethers.getContractFactory("CHRO");
    [ownerOne, ownerTwo, ownerThree, ownerFour] = await ethers.getSigners();
    contract = await Contract.deploy();
    await contract.deployed();
  });

  describe("Deployment", function () {
    it.only("Test mint to 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", async function () {
      await contract.connect(ownerOne).mint("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", ethers.utils.parseEther("900000"))

      const balanceOf = await contract.balanceOf("0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
      expect(ethers.utils.formatEther(balanceOf)).to.equal("900000.0");
    });

    it.only("Get total supply", async function () {
      const balanceOf = await contract.totalSupply();
      expect(ethers.utils.formatEther(balanceOf)).to.equal("900000.0");
      assert.isOk(ethers.utils.formatEther(balanceOf))
    });
  });

  describe("Pausable Test", function () {
    it.only("Test pause", async function () {
      await contract.connect(ownerOne).pause()
      const isPaused = await contract.paused()
      expect(isPaused).to.equal(true)
    });

    it.only("Test unpause", async function () {
      await contract.connect(ownerOne).unpause();
      const isPaused = await contract.paused();

      if (!isPaused) {
        await contract.connect(ownerOne).transfer("0x70997970C51812dc3A010C7d01b50e0d17dc79C8", ethers.utils.parseEther("100"))
      }
    });

    it.only("Balance of 0x709979...7dc79C8 should be 100 CHRO", async function () {
      const balance = await contract.balanceOf("0x70997970C51812dc3A010C7d01b50e0d17dc79C8");
      expect(ethers.utils.formatEther(balance)).to.equal("100.0")
    });
  });
});