const { expect, assert } = require("chai");
const { ethers, upgrades } = require("hardhat");

let chroContract;
let chroContractAddr;
let gameContract;
let gameContractAddr;
let nftContract;
let nftContractAddr;
let nftContract2;
let nftContractAddr2;

describe("Game Development Test", function () {
  before(async function () {
    /// actors
    [owner, user1, user2, royaltyReceiver, treasury] = await ethers.getSigners();

    // deploy all required contracts
    const CHROContract = await ethers.getContractFactory("CHRO");
    chroContract = await CHROContract.deploy();
    await chroContract.deployed();
    chroContractAddr = chroContract.address;

    const NFTContract = await ethers.getContractFactory("WBNFT");
    nftContract = await NFTContract.deploy(royaltyReceiver.address);
    await nftContract.deployed();
    nftContractAddr = nftContract.address;

    const NFTContract2 = await ethers.getContractFactory("WBNFT2");
    nftContract2 = await NFTContract2.deploy();
    await nftContract2.deployed();
    nftContractAddr2 = nftContract2.address;

    const GameContract = await ethers.getContractFactory("WBGame");
    gameContract = await upgrades.deployProxy(GameContract, [nftContractAddr, nftContractAddr2, chroContractAddr]);
    // await gameContract.deployed();
    gameContractAddr = gameContract.address;

    // const GameContract = await ethers.getContractFactory("WBGameV2");
    // gameContract = await upgrades.deployProxy(GameContract, [nftContractAddr, nftContractAddr2, chroContractAddr, treasury.address]);
    // // await gameContract.deployed();
    // gameContractAddr = gameContract.address;

    /*
    const WBGameV2 = await ethers.getContractFactory("WBGameV5");
    gameContract = await upgrades.upgradeProxy(gameContract.address, WBGameV2);
    */
  });

  describe("Configuration", function () {
    it.only('Check ownership', async function () {
      const ownerAddress = await gameContract.owner()
      expect(ownerAddress).to.equal(owner.address)
    });

    it.only('Grant minter role for game contract to collection contract', async function () {
      await nftContract2.connect(owner).addMinter(gameContractAddr)
    });

    it.only('Mint CHRO to buyers', async function () {
      await chroContract.connect(owner).mint(user1.address, ethers.utils.parseEther("1000"))
      const balance = await chroContract.balanceOf(user1.address)
      expect(ethers.utils.formatEther(balance)).to.equal("1000.0")
    });

    it.only('Mint CHRO to Game Contract', async function () {
      await chroContract.connect(owner).mint(gameContractAddr, ethers.utils.parseEther("1000"))
      const balance = await chroContract.balanceOf(gameContractAddr)
      expect(ethers.utils.formatEther(balance)).to.equal("1000.0")
    });

    // it.only('Mint CHRO to Treasury', async function () {
    //   await chroContract.connect(owner).mint(treasury.address, ethers.utils.parseEther("1000"))
    //   const balance = await chroContract.balanceOf(treasury.address)
    //   expect(ethers.utils.formatEther(balance)).to.equal("1000.0")
    // });

    // it.only('Set allowance CHRO for the contract', async function () {
    //   await chroContract.connect(treasury).approve(gameContractAddr, ethers.utils.parseEther("1000"))
    //   const allowance = await chroContract.allowance(treasury.address, gameContractAddr)
    //   expect(ethers.utils.formatEther(allowance)).to.equal("1000.0")
    // });

    it.only('Mint Genesis NFT', async function () {
      await nftContract.connect(user1).mint(3)
      const balance = await nftContract.balanceOf(user1.address)
      expect(balance).to.equal(3)
    });

    it.only('Mint NextGen NFT', async function () {
      await nftContract2.connect(owner).mint(user1.address, 0, 'https://example.com/ipfs/1')
      await nftContract2.connect(owner).mint(user1.address, 0, 'https://example.com/ipfs/2')
      await nftContract2.connect(owner).mint(user1.address, 0, 'https://example.com/ipfs/3')
      const balance = await nftContract2.balanceOf(user1.address)
      expect(balance).to.equal(3)
    });

    it.only('Owner of NFTs', async function () {
      const ownerOf1 = await nftContract.ownerOf(10000)
      const ownerOf2 = await nftContract2.ownerOf(20000)

      expect(ownerOf1).to.equal(user1.address)
      expect(ownerOf2).to.equal(user1.address)
    });
  });

  describe("User Approvals", function () {
    it.only('Set approval for the NFT contract', async function () {
      await nftContract.connect(user1).setApprovalForAll(gameContractAddr, true)
      await nftContract2.connect(user1).setApprovalForAll(gameContractAddr, true)
    });

    it.only('Set allowance CHRO for the contract', async function () {
      await chroContract.connect(user1).approve(gameContractAddr, ethers.utils.parseEther("1000"))
      const allowance = await chroContract.allowance(user1.address, gameContractAddr)
      expect(ethers.utils.formatEther(allowance)).to.equal("1000.0")
    });
  });

  describe("Submit assets to game", function () {
    it.only('User submit their tokens to daily activity place', async function () {
      const tx = await gameContract.connect(user1).batchSubmit(1, [10001]);
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'GameItemTransfer');
      const [sender, contractAddress, collection, tokenId, holderPlace] = event.args;
      const ownerOf1 = await nftContract.ownerOf(10001)
      expect(ownerOf1).to.equal(gameContractAddr)
      // console.log(sender, contractAddress, collection, tokenId, holderPlace);
    });

    it.only('User submit their tokens to breeding place', async function () {
      const tx = await gameContract.connect(user1).batchSubmit(2, [10000, 20000]);
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'GameItemTransfer');
      const [sender, contractAddress, collection, tokenId, holderPlace] = event.args;
      // console.log(sender, contractAddress, collection, tokenId, holderPlace);
    });
  });

  describe("Dispatch assets from game", function () {
    it.only('User dispatch their tokens from daily activity place', async function () {
      const tx = await gameContract.connect(user1).batchDispatch(1, [10001]);
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'GameItemDispatch');
      const [sender, contractAddress, collection, tokenId, holderPlace] = event.args;
      const ownerOf1 = await nftContract.ownerOf(10001)
      expect(ownerOf1).to.equal(user1.address)
      // console.log(sender, contractAddress, collection, tokenId, holderPlace);
    });
    it.only('Admin force dispatch token from breeding place', async function () {
      const tx = await gameContract.connect(owner).safeDispatch(user1.address, 1, 10000);
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'GameItemDispatch');
      const [sender, contractAddress, collection, tokenId, holderPlace] = event.args;
      const ownerOf1 = await nftContract.ownerOf(10000)
      expect(ownerOf1).to.equal(user1.address)
      // console.log(sender, contractAddress, collection, tokenId, holderPlace);
    });
  });

  describe("Daily Activities", function () {
    it.only('User Buy Ticket', async function () {
      const tx = await gameContract.connect(user1).buyTicket(10001, ethers.utils.parseEther("5"), "stage-1")
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'TicketBought');
      const [user, productId, price, activity] = event.args;
      // console.log(user, productId, price, activity);
    });
  });

  describe("Daily Activities Rewards", function () {
    it.only('Admin Set Rewards', async function () {
      const tx = await gameContract.connect(owner).batchSetReward([user2.address], [ethers.utils.parseEther("300")])
      const rc = await tx.wait()
      // const event = rc.events.find(event => event.event === 'TicketBought');
      // const [user, productId, price, activity] = event.args;
      // console.log(user, productId, price, activity);
    });
    // it.only('Set allowance CHRO for the contract', async function () {
    //   const test = await chroContract.approve(gameContractAddr, ethers.utils.parseEther("1000"))
    //   // console.log(test)
    //   // const allowance = await chroContract.allowance(gameContractAddr, gameContractAddr)
    //   // expect(ethers.utils.formatEther(allowance)).to.equal("1000.0")
    // });
    it.only('User Claim Rewards', async function () {
      const tx = await gameContract.connect(user2).claimReward()
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'RewardClaimed');
      const [user, amount, timestamp] = event.args;
      const balance = await chroContract.balanceOf(user2.address)
      expect(ethers.utils.formatEther(balance)).to.equal("300.0")
      // console.log(user, productId, price, activity);
    });
  });

  describe("Breeding Action", function () {
    it.only('User trying to perform 1st breeding', async function () {
      const tx = await gameContract.connect(user1).breed([10000, 20000], 'https://example.com/ipfs/10')
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'BreedItemCreated');
      const [aParent, bParent, child] = event.args;
      // console.log(aParent, bParent, child);
    });

    it.only('User trying to perform 2nd breeding', async function () {
      const tx = await gameContract.connect(user1).breed([10000, 20000], 'https://example.com/ipfs/20')
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'BreedItemCreated');
      const [aParent, bParent, child] = event.args;
      // console.log(aParent, bParent, child);
    });

    it.only('User trying to perform 3rd breeding', async function () {
      const tx = await gameContract.connect(user1).breed([10000, 20000], 'https://example.com/ipfs/30')
      const rc = await tx.wait()
      const event = rc.events.find(event => event.event === 'BreedItemCreated');
      const [aParent, bParent, child] = event.args;
      // console.log(aParent, bParent, child);
    });

    it.only('CHRO balance of P2E', async function () {
      const balance = await chroContract.balanceOf(gameContractAddr)
      expect(ethers.utils.formatEther(balance)).to.equal("1305.0")
    });
  });
});