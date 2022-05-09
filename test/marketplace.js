const { expect, assert } = require("chai");
const { ethers, upgrades } = require("hardhat");

let chroContract;
let chroContractAddr;
let mpContract;
let mpContractAddr;
let mpContractV2;
let nftContract;
let nftContractAddr;
const itemIds = [];
const swapIds = [];

describe("Marketplace Development Test", function () {
  before(async function () {
    /// actors
    [owner, seller, buyer1, buyer2, buyer3, feeCollector1, feeCollector2, royaltyReceiver, publicationFeeWallet] = await ethers.getSigners();

    // deploy all required contracts
    const CHROContract = await ethers.getContractFactory("CHRO");
    chroContract = await CHROContract.deploy();
    await chroContract.deployed();
    chroContractAddr = chroContract.address;

    const NFTContract = await ethers.getContractFactory("WBNFT");
    nftContract = await NFTContract.deploy(royaltyReceiver.address);
    await nftContract.deployed();
    nftContractAddr = nftContract.address;

    const MPContract = await ethers.getContractFactory("Marketplace");
    mpContract = await upgrades.deployProxy(MPContract, [chroContractAddr]);
    // await mpContract.deployed();
    mpContractAddr = mpContract.address;

    // const MarketplaceV2 = await ethers.getContractFactory("MarketplaceV5");
    // mpContract = await upgrades.upgradeProxy(mpContract.address, MarketplaceV2);
  });

  describe("Configuration", function () {
    it.only('Check ownership', async function () {
      const ownerAddress = await mpContract.owner()
      expect(ownerAddress).to.equal(owner.address)
    });

    it.only('Mint CHRO to buyers', async function () {
      await chroContract.connect(owner).mint(seller.address, ethers.utils.parseEther("500"))
      await chroContract.connect(owner).mint(buyer1.address, ethers.utils.parseEther("1000"))
      await chroContract.connect(owner).mint(buyer2.address, ethers.utils.parseEther("2000"))
      await chroContract.connect(owner).mint(buyer3.address, ethers.utils.parseEther("3000"))

      const balance0 = await chroContract.balanceOf(seller.address)
      const balance1 = await chroContract.balanceOf(buyer1.address)
      const balance2 = await chroContract.balanceOf(buyer2.address)
      const balance3 = await chroContract.balanceOf(buyer3.address)

      expect(ethers.utils.formatEther(balance0)).to.equal("500.0")
      expect(ethers.utils.formatEther(balance1)).to.equal("1000.0")
      expect(ethers.utils.formatEther(balance2)).to.equal("2000.0")
      expect(ethers.utils.formatEther(balance3)).to.equal("3000.0")
    });

    it.only('Mint NFT', async function () {
      await nftContract.connect(seller).mint(2)
      await nftContract.connect(buyer1).mint(2)
      await nftContract.connect(buyer2).mint(2)
      await nftContract.connect(buyer3).mint(2)

      const balanceOfSeller = await nftContract.balanceOf(seller.address)
      const balance1 = await nftContract.balanceOf(buyer1.address)
      const balance2 = await nftContract.balanceOf(buyer2.address)
      const balance3 = await nftContract.balanceOf(buyer3.address)

      expect(balanceOfSeller).to.equal(2)
      expect(balance1).to.equal(2)
      expect(balance2).to.equal(2)
      expect(balance3).to.equal(2)
    });

    it.only('Owner of NFTs', async function () {
      const _seller = await nftContract.ownerOf(10000)
      const owner1 = await nftContract.ownerOf(10003)
      const owner2 = await nftContract.ownerOf(10005)
      const owner3 = await nftContract.ownerOf(10007)

      expect(_seller).to.equal(seller.address)
      expect(owner1).to.equal(buyer1.address)
      expect(owner2).to.equal(buyer2.address)
      expect(owner3).to.equal(buyer3.address)
    });
  });

  describe("Owner Capabilities", function () {
    it.only('Add new collection and make sure it was created properly', async function () {
      await mpContract.connect(owner).createCollection(nftContractAddr, true, 'Genesis')

      const collections = await mpContract.getCollections()

      collections.forEach((collection) => {
        expect(collection.active).to.equal(true)
      })
    });

    it.only('Add Fee Collectors', async function () {
      await mpContract.connect(owner).addFeeCollector(feeCollector1.address, 25)
      await mpContract.connect(owner).addFeeCollector(feeCollector2.address, 10)
      // await mpContract.connect(owner).removeFeeCollector(feeCollector2.address)
      const feeCollectors = await mpContract.getFeeCollectors()

      feeCollectors.forEach((feeCollector, i) => {
        // console.log(feeCollector.wallet, feeCollector.percentage)
      })
    });

    it.only('Set publication fees', async function () {
      await mpContract.connect(owner).setPublicationFeeWallet(publicationFeeWallet.address)
      await mpContract.connect(owner).setPublicationFee(0, ethers.utils.parseEther("10"))
      await mpContract.connect(owner).setPublicationFee(1, ethers.utils.parseEther("20"))
      const publicationFees = await mpContract.publicationFees(0)
      expect(ethers.utils.formatEther(publicationFees)).to.equal("10.0")
    });
  });

  describe("User Approvals", function () {
    it.only('Set approval for the NFT contract', async function () {
      await nftContract.connect(seller).setApprovalForAll(mpContractAddr, true)
      await nftContract.connect(buyer1).setApprovalForAll(mpContractAddr, true)
      await nftContract.connect(buyer2).setApprovalForAll(mpContractAddr, true)
      const isApproved = await nftContract.isApprovedForAll(seller.address, mpContractAddr)
      expect(isApproved).to.equal(true)
    });

    it.only('Set allowance CHRO for the contract', async function () {
      await chroContract.connect(seller).approve(mpContractAddr, ethers.utils.parseEther("500"))
      await chroContract.connect(buyer1).approve(mpContractAddr, ethers.utils.parseEther("1000"))
      await chroContract.connect(buyer2).approve(mpContractAddr, ethers.utils.parseEther("2000"))
      await chroContract.connect(buyer3).approve(mpContractAddr, ethers.utils.parseEther("3000"))

      const allowance0 = await chroContract.allowance(seller.address, mpContractAddr)
      const allowance1 = await chroContract.allowance(buyer1.address, mpContractAddr)
      const allowance2 = await chroContract.allowance(buyer2.address, mpContractAddr)
      const allowance3 = await chroContract.allowance(buyer3.address, mpContractAddr)

      expect(ethers.utils.formatEther(allowance0)).to.equal("500.0")
      expect(ethers.utils.formatEther(allowance1)).to.equal("1000.0")
      expect(ethers.utils.formatEther(allowance2)).to.equal("2000.0")
      expect(ethers.utils.formatEther(allowance3)).to.equal("3000.0")
    });
  });

  describe("Initial State", function () {
    it.only('NFT #10001 should be owned by 0x...7dc79C8', async function () {
      const ownerOf = await nftContract.ownerOf(10001)
      expect(ownerOf).to.equal(seller.address)
    });

    it.only('Balance of 0x...E93b906 should be 2000 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(buyer2.address)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("2000.0")
    });
  });

  describe("NFT Sales", function () {
    it.only('Direct sale NFT to the marketplace', async function () {
      const tx = await mpContract.connect(seller).sell(nftContractAddr, 10000, ethers.utils.parseEther("300"))
      const rc = await tx.wait();
      const event = rc.events.find(event => event.event === 'ItemCreated')
      const [itemId] = event.args
      itemIds.push(itemId);

      const sellerOf = await mpContract.sellerOf(nftContractAddr, 10000)
      expect(sellerOf).to.equal(seller.address)
    });

    it.only('Auction sale NFT to the marketplace', async function () {
      const tx = await mpContract.connect(seller).auction(nftContractAddr, 10001, ethers.utils.parseEther("300"), 1649279531)
      const rc = await tx.wait();
      const event = rc.events.find(event => event.event === 'ItemCreated')
      const [itemId] = event.args
      itemIds.push(itemId);

      const sellerOf = await mpContract.sellerOf(nftContractAddr, 10001)
      expect(sellerOf).to.equal(seller.address)
    });

    it.only('0x...a4293bc request to swap NFTs between #10003 and #10005', async function () {
      const tx = await mpContract.connect(buyer1).swap(nftContractAddr, 10003, nftContractAddr, 10005)
      const rc = await tx.wait();
      const event = rc.events.find(event => event.event === 'SwapCreated')
      const [swapId] = event.args
      swapIds.push(swapId)
    });
  });

  describe("NFT buy and bidding", function () {
    it.only('Buy NFT from direct sales', async function () {
      const itemId = itemIds[0]
      await mpContract.connect(buyer1).buy(itemId)
      const ownerOf = await nftContract.ownerOf(10000)
      expect(ownerOf).to.equal(buyer1.address)
    });

    it.only('Bid NFT from auction sales', async function () {
      const itemId = itemIds[1]
      await mpContract.connect(buyer1).bid(itemId, ethers.utils.parseEther("400"))
      const bid = await mpContract.getBid(itemId, 0)
      expect(bid.bidder).to.equal(buyer1.address)
      expect(ethers.utils.formatEther(bid.price)).to.equal('400.0')

      await mpContract.connect(buyer2).bid(itemId, ethers.utils.parseEther("450"))
      const bid2 = await mpContract.getBid(itemId, 1)
      expect(bid2.bidder).to.equal(buyer2.address)
      expect(ethers.utils.formatEther(bid2.price)).to.equal('450.0')
    });

    it.only('0x...e93b906 approve swap from 0x...a4293bc', async function () {
      const swapId = swapIds[0]
      // console.log(buyer2.address)
      await mpContract.connect(buyer2).approveSwap(swapId)
    });
  });

  describe("Job Execution", function () {
    it.only('Job execution every midnight', async function () {
      await mpContract.connect(owner).executeJob()
      const ownerOf = await nftContract.ownerOf(10001)
      expect(ownerOf).to.equal(buyer2.address)
    });
  });

  describe("Final state", function () {
    it.only('NFT #10001 should be owned by 0x...E93b906', async function () {
      const ownerOf = await nftContract.ownerOf(10001)
      expect(ownerOf).to.equal(buyer2.address)
    });

    it.only('Balance of 0x...E93b906 should be 1550 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(buyer2.address)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("1550.0")
    });

    it.only('Balance of marketplace should be 0 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(mpContractAddr)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("0.0")
    });

    it.only('Balance of fee collector 1 should be 18.75 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(feeCollector1.address)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("18.75")
    });

    it.only('Balance of fee collector 2 should be 7.5 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(feeCollector2.address)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("7.5")
    });

    it.only('Balance of publication wallet fee should be 30 CHRO', async function () {
      const balanceOf = await chroContract.balanceOf(publicationFeeWallet.address)
      expect(ethers.utils.formatEther(balanceOf)).to.equal("30.0")
    });

    it.only('Get items', async function () {
      const items = await mpContract.getItems(0,3)
      const item = await mpContract.getItem(items[1][0])
      console.log(item)
    });

    it.only('Get swaps', async function () {
      const items = await mpContract.getSwaps(0,3)
      const item = await mpContract.getSwap(items[1][0])
      console.log(item)
    });
  });

  /*
  describe("Upgrade Contract", function () {
    before(async function () {
      const MarketplaceV2 = await ethers.getContractFactory("MarketplaceV2");
      mpContractV2 = await upgrades.upgradeProxy(mpContract.address, MarketplaceV2);
    })

    it.only('Check ownership', async function () {
      const ownerAddress = await mpContractV2.owner()
      expect(ownerAddress).to.equal(owner.address)
    });

    it.only('Get previous bids', async function () {
      const bids = await mpContractV2.getBids(itemIds[1])
      // console.log(bids)
    });

    it.only('Get previous fee collectors', async function () {
      const feeCollectors = await mpContractV2.getFeeCollectors()
      console.log(feeCollectors)
    });

    it.only('Get previous collections', async function () {
      const collections = await mpContractV2.getCollections()
      console.log(collections)
    });
  });
  */
});