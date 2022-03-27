const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

let chroContract;
let chroContractAddr;
let usdContract;
let usdContractAddr;
let multisigContract;
let multisigContractAddr;
let privateSalesContract;
let privateSalesContractAddr;

// set to Sunday, March 27, 2022 12:00:00 PM GMT+07:00
const vestingStartTime = 1648357200;
const vestingPeriod = 3600;
const vestingDivider = 4;

describe("Private Sales Development Test", function () {
  before(async function () {
    [address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();

    // deploy all required contracts
    const CHROContract = await ethers.getContractFactory("CHRO");
    chroContract = await CHROContract.deploy();
    await chroContract.deployed();
    chroContractAddr = chroContract.address;

    const USDContract = await ethers.getContractFactory("USDTest");
    usdContract = await USDContract.deploy();
    await usdContract.deployed();
    usdContractAddr = usdContract.address;

    const WBMultiSigWallet = await ethers.getContractFactory("WBMultiSigWallet");
    multisigContract = await WBMultiSigWallet.deploy();
    await multisigContract.deployed();
    multisigContractAddr = multisigContract.address;

    const PrivateSales = await ethers.getContractFactory("CHROPrivateSales");
    privateSalesContract = await PrivateSales.deploy(chroContractAddr, usdContractAddr, multisigContractAddr);
    await privateSalesContract.deployed();
    privateSalesContractAddr = privateSalesContract.address;
  });

  describe("Pre-Configuration", function () {
    /*
    it.only('Check all contract addresses', async function () {
      console.log('CHRO ADDRESS:', chroContractAddr)
      console.log('USD ADDRESS:', usdContractAddr)
      console.log('MULTISIG ADDRESS:', multisigContractAddr)
      console.log('PRIVATE SALES ADDRESS:', privateSalesContractAddr)
    });
    */
    it.only('CHRO: Allocating 600K of CHRO to the private sales contract', async function () {
      await chroContract.connect(address1).mint(privateSalesContractAddr, ethers.utils.parseEther("600000"))
      const balance = await privateSalesContract.getTokenBalance()
      expect(ethers.utils.formatEther(balance)).to.equal("600000.0")
    });

    it.only('USDC: Allocationg USD to some user addresses for each $1000', async function () {
      await usdContract.connect(address1).mint(address2.address, 1000000000)
      await usdContract.connect(address1).mint(address3.address, 1000000000)
      await usdContract.connect(address1).mint(address4.address, 1000000000)
      
      // one sample
      const balance = await usdContract.balanceOf(address2.address)
      expect(balance).to.equal(1000000000)
    });

    it.only('PRIVATE SALES: Adding whitelist to private sales', async function () {
      await privateSalesContract.connect(address1).batchAddWhitelist([address2.address, address3.address, address4.address], [1000000000, 1000000000, 1000000000])
      
      // one sample
      const allocation = await privateSalesContract.getAllocation(address2.address)
      expect(allocation).to.equal(1000000000)
    });

    it.only('PRIVATE SALES: Starting private sales', async function () {
      await privateSalesContract.connect(address1).startSales()
      const isStarted = await privateSalesContract.isStarted()
      expect(isStarted).to.equal(true)
    });

    it.only('USD: Allowance approval of USD', async function () {
      await usdContract.connect(address2).approve(privateSalesContractAddr, 1000000000)
      await usdContract.connect(address3).approve(privateSalesContractAddr, 1000000000)
      await usdContract.connect(address4).approve(privateSalesContractAddr, 1000000000)

      // one sample
      const allowance = await usdContract.allowance(address2.address, privateSalesContractAddr)
      expect(allowance).to.equal(1000000000)
    });

    it.only('PRIVATE SALES: Set vesting period', async function () {
      await privateSalesContract.connect(address1).setPeriod(vestingStartTime, vestingPeriod, vestingDivider)

      // one sample
      const startTime = await privateSalesContract.start()
      expect(startTime).to.equal(vestingStartTime)

      const releaseSchedule = await privateSalesContract.releaseSchedule(0)
      console.log(releaseSchedule)
    });
  });

  describe("Expected Workflow", function () {
    it.only('PRIVATE SALES: User buying CHRO', async function () {
      await privateSalesContract.connect(address2).buyTokens(1000000000)
      
      // one sample to get user's balance(purchased CHRO) and released CHRO
      const account = await privateSalesContract.getAccount(address2.address)
      expect(ethers.utils.formatEther(account.balance)).to.equal("25000.0")
      expect(ethers.utils.formatEther(account.released)).to.equal("0.0")
    });

    it.only('USD: USD balance of the user should be decreased', async function () {
      const balance = await usdContract.balanceOf(address2.address)
      expect(balance).to.equal(0)
    });

    it.only('MULTISIG: USD balance of the multisig should be increased', async function () {
      const balance = await usdContract.balanceOf(multisigContractAddr)
      expect(balance).to.equal(1000000000)
    });

    it.only('PRIVATE SALES: Check balance of allocation before the user perform claim', async function () {
      const balance = await privateSalesContract.getTokenBalance()
      expect(balance).to.equal(ethers.utils.parseEther("575000"))
    });

    it.only('PRIVATE SALES: Check sold tokens', async function () {
      const tokensSold = await privateSalesContract.tokensSold()
      expect(tokensSold).to.equal(ethers.utils.parseEther("25000"))
    });

    it.only('PRIVATE SALES: Get vested amount of the user with given timestamp', async function () {
      /**
       *  1648360800 1648360883 4
          1648359900 1648360883 3
          1648359000 1648360883 2
          1648358100 1648360883 1
       */
      // const vestedAmount = await privateSalesContract.vestedAmount(address2.address, 1648358100)
      // const vestedAmount2 = await privateSalesContract.vestedAmount(address2.address, 1648359000)
      // const vestedAmount3 = await privateSalesContract.vestedAmount(address2.address, 1648359900)
      // const vestedAmount4 = await privateSalesContract.vestedAmount(address2.address, 1648360800)
      // expect(vestedAmount).to.equal(ethers.utils.parseEther("25000"))
      // console.log(ethers.utils.formatEther(vestedAmount), ethers.utils.formatEther(vestedAmount2), ethers.utils.formatEther(vestedAmount3), ethers.utils.formatEther(vestedAmount4))
    });

    it.only('PRIVATE SALES: Release claimable token', async function () {
      await privateSalesContract.connect(address2).release()

      // try to re-release in one same of period, it's should be thrown an error
      await privateSalesContract.connect(address2).release()

      const CHROBalance = await chroContract.balanceOf(address2.address)
      expect(CHROBalance).to.equal(ethers.utils.parseEther("25000"))
    });
  });

    /*
    it('Check owner', async function () {
      const owner = await contract.owner()
      expect(owner).to.equal(address1.address)
    });

    it('Vesting Period', async function () {
      const startTime = Math.ceil(Date.now() / 1000)
      await contract.connect(address1).setPeriod(startTime, 86400)
      const start = await contract.start();
      const duration = await contract.duration()
      const balance = await contract.getBalance()
      console.log(start)
      console.log(duration)
      console.log(balance)
    });
    */
});