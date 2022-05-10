//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Marketplace is OwnableUpgradeable, PausableUpgradeable, ERC721Holder {
  using SafeMath for uint256;
  using AddressUpgradeable for address;

  IERC20 private _tokenContract;

  event CollectionCreated(address indexed nftContractAddress);
  event CollectionRemoved(address indexed nftContractAddress);
  event CollectionUpdated(address indexed nftContractAddress, bool active);

  event FeeCollectorCreated(
    uint indexed index,
    address wallet,
    uint256 percentage
  );

  event FeeCollectorRemoved(
    uint indexed index,
    address wallet
  );

  event ItemCreated(
    bytes32 itemId,
    uint256 indexed tokenId,
    address indexed seller,
    address nftAddress,
    uint256 price,
    uint256 expiresAt,
    SaleType saleType
  );

  event ItemCancelled(bytes32 indexed itemId, SaleStatus saleStatus, address user);
  event ItemSold(bytes32 indexed itemId, SaleStatus saleStatus, address user);
  event ItemBid(bytes32 indexed itemId, address user);
  event ItemExpired(bytes32 indexed itemId, SaleStatus saleStatus, address user);

  event SwapCreated(
    bytes32 indexed swapId,
    address fromCollection,
    uint256 fromTokenId,
    address fromUser,
    address toCollection,
    uint256 toTokenId,
    address toUser
  );

  event SwapApproved(bytes32 indexed swapId, address user);
  event SwapRejected(bytes32 indexed swapId, address user);
  event SwapCancelled(bytes32 indexed swapId, address user);
  event AuctionExpiryExecuted(bytes32 _itemId, address user);

  enum SaleType {
    Direct,
    Auction
  }

  enum SaleStatus {
    Open,
    Sold,
    Cancel,
    Reject,
    Expired
  }

  struct Bid {
    address bidder;
    uint256 price;
    uint256 createdAt;
    bool selected;
  }

  struct Item {
    address nftAddress;
    uint256 tokenId;
    uint256 price;
    address seller;
    address buyer;
    uint256 createdAt;
    uint256 expiresAt;
    uint256 topBidIndex;
    uint256 topBidPrice;
    address topBidder;
    Bid[] bids;
    SaleType saleType;
    SaleStatus saleStatus;
  }

  mapping (bytes32 => Item) private _items;

  struct AuctionExpiry {
    bytes32 itemId;
    uint expiresAt;
    bool executed;
  }

  AuctionExpiry[] private _auctionExpiry;

  struct Collection {
    bool active;
    bool royaltySupported;
    string name;
  }

  mapping (address => Collection) public collections;

  struct FeeCollector {
    address wallet;
    uint256 percentage;
  }

  FeeCollector[] private _feeCollectors;

  struct Swap {
    address fromCollection;
    uint256 fromTokenId;
    address fromUser;
    address toCollection;
    uint256 toTokenId;
    address toUser;
    uint256 createdAt;
    SaleStatus saleStatus;
  }

  mapping (bytes32 => Swap) public swaps;

  address private jobExecutor;
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
  address[] private _collectionIndex;
  uint256 public bidThreshold;

  /// mapping itemId => userAddress => amount
  mapping (bytes32 => mapping (address => uint256)) private _holdTokens;

  /// mapping collectionAddress => tokenId => ownerAddress
  mapping (address => mapping (uint256 => address)) private _holdNFTs;

  /// mapping saleType => percentage
  mapping (SaleType => uint256) public publicationFees;
  address private _publicationFeeWallet;

  bytes32[] private _itemIndex;
  mapping (bytes32 => Swap) private _swaps;
  bytes32[] private _swapIndex;

  /**
   * @dev Sets for token address
   * @param _tokenAddress Token address
   */
  function initialize(address _tokenAddress) public initializer {
    _transferOwnership(_msgSender());
    setTokenAddress(_tokenAddress);
    setJobExecutor(_msgSender());
    bidThreshold = 50;
  }

  /**
   * @dev Only executor
   */
  modifier onlyExecutor() {
    require(jobExecutor == _msgSender(), "Caller is not job executor");
    _;
  }

  ///--------------------------------- PUBLIC FUNCTIONS ---------------------------------

  /**
   * @dev Seller of NFT
   * @param _nftContractAddress Collection address
   * @param _tokenId Token id
   * @return address Seller address
   */
  function sellerOf(
    address _nftContractAddress,
    uint256 _tokenId
  ) public view returns(address) {
    return _holdNFTs[_nftContractAddress][_tokenId];
  }

  /**
   * @dev Auction sell
   * @param _nftContractAddress NFT contract address
   * @param _tokenId NFT token id
   * @param _price NFT initial price 
   * @param _expiresAt Expiry timestamp in UTC
   */
  function auction(
    address _nftContractAddress,
    uint256 _tokenId,
    uint256 _price,
    uint256 _expiresAt
  ) public whenNotPaused {
    _isActiveCollection(_nftContractAddress);
    _createItem(_nftContractAddress, _tokenId, _price, _expiresAt, SaleType.Auction);
  }

  /**
   * @dev Direct sell
   * @param _nftContractAddress NFT contract address
   * @param _tokenId NFT token id
   * @param _price NFT price
   */
  function sell(
    address _nftContractAddress,
    uint256 _tokenId,
    uint256 _price
  ) public whenNotPaused {
    _isActiveCollection(_nftContractAddress);
    _createItem(_nftContractAddress, _tokenId, _price, 0, SaleType.Direct);
  }

  /**
   * @dev Cancel market item
   * @param _itemId Item id
   */
  function cancel(bytes32 _itemId) public whenNotPaused {
    Item storage item = _items[_itemId];

    require(item.seller == _msgSender(), "Not token owner");
    require(item.bids.length == 0, "Bid exists");
    require(item.saleStatus == SaleStatus.Open || item.saleStatus == SaleStatus.Expired, "Item is unavailable");

    /// release nft and transfer it to the seller
    IERC721 nftRegistry = IERC721(item.nftAddress);
    nftRegistry.safeTransferFrom(address(this), item.seller, item.tokenId);
    delete _holdNFTs[item.nftAddress][item.tokenId];

    item.saleStatus = SaleStatus.Cancel;

    emit ItemCancelled(_itemId, SaleStatus.Cancel, _msgSender());
  }

  /**
   * @dev Buy NFT from direct sales
   * @param _itemId Item ID
   */
  function buy(bytes32 _itemId) public whenNotPaused {
    Item storage item = _items[_itemId];

    _executePayment(_itemId, _msgSender());

    item.buyer = _msgSender();
    item.saleStatus = SaleStatus.Sold;

    IERC721(item.nftAddress).transferFrom(address(this), _msgSender(), item.tokenId);
    delete _holdNFTs[item.nftAddress][item.tokenId];

    emit ItemSold(_itemId, SaleStatus.Sold, _msgSender());
  }

  /**
   * @dev Bid to auction sales
   * @param _itemId Item ID
   */
  function bid(
    bytes32 _itemId,
    uint256 _price
  ) public whenNotPaused {
    Item storage item = _items[_itemId];

    require(_price >= (item.topBidPrice.add(item.topBidPrice.div(1000).mul(bidThreshold))), "Minimum bid price is required");
    require(_tokenContract.balanceOf(_msgSender()) >= _price, "Not enough tokens");
    require(_tokenContract.allowance(_msgSender(), address(this)) >= _price, "Not enough allowance");

    if (item.saleType == SaleType.Auction && item.saleStatus == SaleStatus.Open) {
      uint256 bidIndex = 0;

      if (item.bids.length > 0) {
        bidIndex = item.bids.length - 1;

        if (_holdTokens[_itemId][item.topBidder] > 0) {
          _releaseHoldAmount(_itemId, item.topBidder, item.topBidder, item.topBidPrice);
        }
      }
      
      item.bids.push(Bid({
        bidder: _msgSender(),
        price: _price,
        createdAt: block.timestamp,
        selected: false
      }));

      _putHoldAmount(_itemId, _msgSender(), _price);

      item.topBidIndex = bidIndex;
      item.topBidPrice = _price;
      item.topBidder = _msgSender();
      
      if (item.expiresAt.sub(600) < block.timestamp && item.expiresAt > block.timestamp) {
        item.expiresAt = item.expiresAt.add(600);
      }

      emit ItemBid(_itemId, _msgSender());
    }
  }

  /**
   * @dev Swap request
   * @param _fromCollection Collection ID
   * @param _fromTokenId Item ID
   * @param _toCollection Collection ID
   * @param _toTokenId Item ID
   */
  function swap(
    address _fromCollection,
    uint256 _fromTokenId,
    address _toCollection,
    uint256 _toTokenId
  ) public whenNotPaused {
    _isActiveCollection(_fromCollection);
    _isActiveCollection(_toCollection);

    IERC721 fromCollection = IERC721(_fromCollection);
    IERC721 toCollection = IERC721(_toCollection);

    address fromTokenOwner = fromCollection.ownerOf(_fromTokenId);
    address toTokenOwner = toCollection.ownerOf(_toTokenId);

    require(_msgSender() == fromTokenOwner, "Not token owner");
    require(
      (fromCollection.getApproved(_fromTokenId) == address(this) || fromCollection.isApprovedForAll(fromTokenOwner, address(this))) && (toCollection.getApproved(_toTokenId) == address(this) || toCollection.isApprovedForAll(toTokenOwner, address(this))),
      "The contract is not authorized"
    );

    bytes32 swapId = keccak256(
      abi.encodePacked(
        block.timestamp,
        _fromCollection,
        _fromTokenId,
        _toCollection,
        _toTokenId
      )
    );

    _swaps[swapId] = Swap({
      fromCollection: _fromCollection,
      fromTokenId: _fromTokenId,
      fromUser: fromTokenOwner,
      toCollection: _toCollection,
      toTokenId: _toTokenId,
      toUser: toTokenOwner,
      createdAt: block.timestamp,
      saleStatus: SaleStatus.Open
    });

    _swapIndex.push(swapId);

    emit SwapCreated(swapId, _fromCollection, _fromTokenId, fromTokenOwner, _toCollection, _toTokenId, toTokenOwner);
  }

  /**
   * @dev Approve swap by receiver of NFT
   * @param _swapId Swap ID
   */
  function approveSwap(bytes32 _swapId) public whenNotPaused {
    Swap storage _swap = _swaps[_swapId];

    IERC721 fromCollection = IERC721(_swap.fromCollection);
    IERC721 toCollection = IERC721(_swap.toCollection);

    require(_swap.toUser == _msgSender(), "Not token owner");
    require((fromCollection.ownerOf(_swap.fromTokenId) == _swap.fromUser) && (toCollection.ownerOf(_swap.toTokenId) == _msgSender()), "Not token owner");
    require(
      (fromCollection.getApproved(_swap.fromTokenId) == address(this) || fromCollection.isApprovedForAll(_swap.fromUser, address(this))) && (toCollection.getApproved(_swap.toTokenId) == address(this) || toCollection.isApprovedForAll(_swap.toUser, address(this))),
      "The contract is not authorized"
    );

    fromCollection.transferFrom(_swap.fromUser, _swap.toUser, _swap.fromTokenId);
    toCollection.transferFrom(_swap.toUser, _swap.fromUser, _swap.toTokenId);

    _swap.saleStatus = SaleStatus.Sold;
  }

  /**
   * @dev Reject swap by receiver of NFT
   * @param _swapId Swap ID
   */
  function rejectSwap(bytes32 _swapId) public whenNotPaused {
    Swap storage _swap = _swaps[_swapId];
    require(_swap.toUser == _msgSender(), "Not token owner");
    _swap.saleStatus = SaleStatus.Reject;

    emit SwapRejected(_swapId, _swap.toUser);
  }

  /**
   * @dev Cancel swap by owner of NFT
   * @param _swapId Swap ID
   */
  function cancelSwap(bytes32 _swapId) public whenNotPaused {
    Swap storage _swap = _swaps[_swapId];
    require(_swap.fromUser == _msgSender(), "Not token owner");
    _swap.saleStatus = SaleStatus.Cancel;

    emit SwapCancelled(_swapId, _swap.fromUser);
  }

  /**
   * @dev Get auction expiry
   * @return AuctionExpiry Array of auction expiry
   */
  function getAuctionExpiry() public view returns(AuctionExpiry[] memory) {
    AuctionExpiry[] memory auctionData = new AuctionExpiry[](_auctionExpiry.length);

    for (uint256 i = 0; i < _auctionExpiry.length; i++) {
      AuctionExpiry storage auctionExpiry = _auctionExpiry[i];
      
      if (auctionExpiry.expiresAt < block.timestamp && !auctionExpiry.executed) {
        auctionData[i] = auctionExpiry;
      }
    }

    return auctionData;
  }

  /**
   * @dev Get items with pagination supported
   * @param _startIndex Start with index number
   * @param _endIndex End with index number
   * @return uint256 Total of items
   * @return bytes32[] Array of item ids
   */
  function getItems(
    uint _startIndex,
    uint _endIndex
  ) public view returns(uint256, bytes32[] memory) {
    bytes32[] memory itemData = new bytes32[](_itemIndex.length);
    
    if (_startIndex >= _itemIndex.length) {
      _startIndex = 0;
    }

    if (_endIndex >= _itemIndex.length) {
      _endIndex = _itemIndex.length.sub(1);
    }

    for (uint i = _startIndex; i <= _endIndex; i++) {
      itemData[i] = _itemIndex[i];
    }

    return (_itemIndex.length, itemData);
  }

  /**
   * @dev Get item details
   * @param _itemId Item id
   * @return Item Item details
   */
  function getItem(bytes32 _itemId) public view returns(Item memory) {
    Item storage item = _items[_itemId];
    return item;
  }

  /**
   * @dev Get all bids of the item
   * @param _itemId Item id
   * @return Bid Array of bids
   */
  function getBids(bytes32 _itemId) public view returns(Bid[] memory) {
    Item storage item = _items[_itemId];
    Bid[] memory bidData = new Bid[](item.bids.length);

    for (uint256 i = 0; i < item.bids.length; i++) {
      Bid storage bidItem = item.bids[i];
      bidData[i] = bidItem;
    }

    return bidData;
  }

  /**
   * @dev Get bid details
   * @param _itemId Sale item id
   * @param _bidIndex Index of bid
   * @return Bid Struct of bid
   */
  function getBid(bytes32 _itemId, uint _bidIndex) public view returns(Bid memory) {
    Item storage item = _items[_itemId];
    return item.bids[_bidIndex];
  }

  /**
   * @dev Get list of swap ids
   * @param _startIndex Start with index number
   * @param _endIndex End with index number
   */
  function getSwaps(
    uint _startIndex,
    uint _endIndex
  ) public view returns(uint256, bytes32[] memory) {
    bytes32[] memory itemData = new bytes32[](_swapIndex.length);
    
    if (_startIndex >= _swapIndex.length) {
      _startIndex = 0;
    }

    if (_endIndex >= _swapIndex.length) {
      _endIndex = _swapIndex.length.sub(1);
    }

    for (uint i = _startIndex; i <= _endIndex; i++) {
      itemData[i] = _swapIndex[i];
    }

    return (_swapIndex.length, itemData);
  }

  /**
   * @dev Get swap details
   * @param _itemId Swap id
   */
  function getSwap(bytes32 _itemId) public view returns(Swap memory) {
    Swap storage item = _swaps[_itemId];
    return item;
  }

  /**
   * @dev Get royalty info
   * @param _tokenId Token id
   * @param _salePrice Token sale price
   */
  function getRoyaltyInfo(address _nftContractAddress, uint256 _tokenId, uint256 _salePrice)
    external
    view
    returns(address receiverAddress, uint256 royaltyAmount)
  {
    return _getRoyaltyInfo(_nftContractAddress, _tokenId, _salePrice);
  }

  /**
   * @dev Tells wether royalty is supported or not
   * @param _nftContractAddress Collection address
   * @return bool
   */
  function checkRoyalties(address _nftContractAddress)
    external
    view
    returns(bool)
  {
    return _isRoyaltiesSupport(_nftContractAddress);
  }

  ///--------------------------------- ADMINISTRATION FUNCTIONS ---------------------------------

  /**
   * @dev Set ERC20 contract address
   * @param _tokenAddress ERC20 contract address
   */
  function setTokenAddress(address _tokenAddress) public onlyOwner {
    _tokenContract = IERC20(_tokenAddress);
  }

  /**
   * @dev Pause the public function
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @dev Unpause the public function
   */
  function unpause() public onlyOwner {
    _unpause();
  }

  /**
   * @dev Get collections
   * @return Collection Collection array
   */
  function getCollections() public view returns(Collection[] memory) {
    Collection[] memory collectionArray = new Collection[](_collectionIndex.length);

    for (uint256 i = 0; i < _collectionIndex.length; i++) {
      Collection storage collection = collections[_collectionIndex[i]];
      collectionArray[i] = collection;
    }

    return collectionArray;
  }

  /**
   * @dev Create collection
   * @param _nftContractAddress NFT contract address for the collection
   * @param _active Active status of the collection
   */
  function createCollection(
    address _nftContractAddress,
    bool _active,
    string memory _name
  ) public onlyOwner {
    _requireERC721(_nftContractAddress);

    collections[_nftContractAddress] = Collection({
      active: _active,
      royaltySupported: _isRoyaltiesSupport(_nftContractAddress),
      name: _name
    });

    _collectionIndex.push(_nftContractAddress);
    
    emit CollectionCreated(_nftContractAddress);
  }

  /**
   * @dev Remove collection
   * @param _nftContractAddress NFT contract address for the collection
   */
  function removeCollection(address _nftContractAddress) public onlyOwner {
    delete collections[_nftContractAddress];

    for (uint i = 0; i < _collectionIndex.length; i++) {
      if (_collectionIndex[i] == _nftContractAddress) {
        _collectionIndex[i] = _collectionIndex[_collectionIndex.length - 1];
      }
    }

    _collectionIndex.pop();

    emit CollectionRemoved(_nftContractAddress);
  }

  /**
   * @dev Update collection
   * @param _nftContractAddress NFT contract address
   * @param _active Active status of the collection
   */
  function updateCollection(
    address _nftContractAddress,
    bool _active
  ) public onlyOwner {
    Collection storage collection = collections[_nftContractAddress];
    collection.active = _active;

    emit CollectionUpdated(
      _nftContractAddress,
      _active
    );
  }

  /**
   * @dev Get fee collectors
   * @return FeeCollector Array of fee collectors
   */
  function getFeeCollectors() public view onlyOwner returns(FeeCollector[] memory) {
    FeeCollector[] memory feeCollectorArray = new FeeCollector[](_feeCollectors.length);

    for (uint256 i = 0; i < _feeCollectors.length; i++) {
      FeeCollector storage feeCollector = _feeCollectors[i];
      feeCollectorArray[i] = feeCollector;
    }

    return feeCollectorArray;
  }

  /**
   * @dev Add fee collector
   * @param _wallet Wallet address
   * @param _percentage Percentage amount (dividing for 1000)
   */
  function addFeeCollector(
    address _wallet,
    uint256 _percentage
  ) public onlyOwner {
    _feeCollectors.push(FeeCollector({
      wallet: _wallet,
      percentage: _percentage
    }));

    uint index = _feeCollectors.length;

    emit FeeCollectorCreated(
      index,
      _wallet,
      _percentage
    );
  }

  /**
   * @dev Remove fee collector
   * @param _wallet FeeCollector address
   */
  function removeFeeCollector(address _wallet) public onlyOwner {
    FeeCollector memory removedFeeCollector;
    uint _index = 0;
    for (uint i = 0; i < _feeCollectors.length; i++) {
      if (_feeCollectors[i].wallet == _wallet) {
        _feeCollectors[i] = _feeCollectors[_feeCollectors.length - 1];
        _feeCollectors[_feeCollectors.length - 1] = removedFeeCollector;
        _index = i;
      }
    }

    _feeCollectors.pop();

    emit FeeCollectorRemoved(
      _index,
      _wallet
    );
  }

  /**
   * @dev Owner can transfer NFT to the user for emergency purpose
   * @param _nftContractAddress NFT contract address
   * @param _tokenId Token id
   * @param _to Receiver address
   */
  function emergencyTransferTo(
    address _nftContractAddress,
    address _to,
    uint256 _tokenId
  ) public onlyOwner {
    IERC721(_nftContractAddress).safeTransferFrom(address(this), _to, _tokenId);
  }

  /**
   * @dev Emergency cancel(de-listing) sale item by admin
   * @dev This cancellation is remove NFT from storage but still owned by this contract
   * @dev So we need to transfer out manually by calling emergencyTransferTo() function
   * @param _itemId Item id
   */
  function emergencyCancel(bytes32 _itemId) public onlyOwner {
    Item storage item = _items[_itemId];
    require(item.saleStatus == SaleStatus.Open, "Item is unavailable");
    delete _holdNFTs[item.nftAddress][item.tokenId];

    /// revoke last bid if exists
    if (item.bids.length > 0) {
      _releaseHoldAmount(_itemId, item.topBidder, item.topBidder, item.topBidPrice);
    }

    item.saleStatus = SaleStatus.Reject;

    emit ItemCancelled(_itemId, SaleStatus.Reject, _msgSender());
  }

  /**
   * @dev Set job executor
   * @param _jobExecutor Job executor address
   */
  function setJobExecutor(address _jobExecutor) public onlyOwner {
    jobExecutor = _jobExecutor;
  }
  
  /**
   * @dev Set bid threshold
   * @param _percentage Percentage
   */
  function setBidThreshold(uint256 _percentage) public onlyOwner {
    bidThreshold = _percentage;
  }

  /**
   * @dev Set publication fee
   * @param _saleType Sales type
   * @param _amount Fixed amount
   */
  function setPublicationFee(SaleType _saleType, uint256 _amount) public onlyOwner {
    publicationFees[_saleType] = _amount;
  }

  /**
   * @dev Set the address of publication fee
   * @param _wallet Wallet address
   */
  function setPublicationFeeWallet(address _wallet) public onlyOwner {
    _publicationFeeWallet = _wallet;
  }

  /**
   * @dev Get the address of publication fee
   * @return address
   */
  function getPublicationFeeWallet() public onlyOwner view returns(address) {
    return _publicationFeeWallet;
  }

  /**
   * @dev This function is used for executes all expired auctions
   * System will automatically select the highest price
   */
  function executeJob() public onlyExecutor {
    for (uint256 i = 0; i < _auctionExpiry.length; i++) {
      AuctionExpiry storage auctionExpiry = _auctionExpiry[i];
      
      if (auctionExpiry.expiresAt < block.timestamp && !auctionExpiry.executed) {
        Item storage item = _items[auctionExpiry.itemId];

        if (item.saleStatus == SaleStatus.Open) {
          if (item.bids.length > 0) {
            item.buyer = item.topBidder;
            item.price = item.topBidPrice;
            item.saleStatus = SaleStatus.Sold;
            
            _executePayment(auctionExpiry.itemId, item.buyer);
            
            IERC721(item.nftAddress).transferFrom(address(this), item.buyer, item.tokenId);
            delete _holdNFTs[item.nftAddress][item.tokenId];

            for (uint256 j = 0; j < item.bids.length; j++) {
              if (item.bids[j].price == item.topBidPrice && item.bids[j].bidder == item.topBidder) {
                item.bids[j].selected = true;
                break;
              }
            }

            emit ItemSold(auctionExpiry.itemId, SaleStatus.Sold, _msgSender());
          } else {
            IERC721(item.nftAddress).transferFrom(address(this), item.seller, item.tokenId);
            delete _holdNFTs[item.nftAddress][item.tokenId];
            item.saleStatus = SaleStatus.Expired;
            emit ItemExpired(auctionExpiry.itemId, SaleStatus.Expired, _msgSender());
          }

          emit AuctionExpiryExecuted(auctionExpiry.itemId, _msgSender());
        }
      }
    }
  }

  ///--------------------------------- INTERNAL FUNCTIONS ---------------------------------

  /**
   * @dev Hold tokens by transfer amount of the bidder to this contract
   */
  function _putHoldAmount(
    bytes32 _itemId,
    address _user,
    uint256 _amount
  ) internal {
    _holdTokens[_itemId][_user] = _holdTokens[_itemId][_user].add(_amount);
    _tokenContract.transferFrom(_user, address(this), _amount);
  }

  /**
   * @dev Sent back the held amount of the previous loser to their wallet
   * @param _itemId Item id
   * @param _user Wallet address of the user
   * @param _to Receiver wallet
   * @param _amount Amount of tokens
   */
  function _releaseHoldAmount(
    bytes32 _itemId,
    address _user,
    address _to,
    uint256 _amount
  ) internal {
    _holdTokens[_itemId][_user] = _holdTokens[_itemId][_user].sub(_amount);
    _tokenContract.transfer(_to, _amount);
  }

  function _isRoyaltiesSupport(address _nftContractAddress)
    private
    view
    returns(bool)
  {
    (bool success) = IERC2981(_nftContractAddress).supportsInterface(_INTERFACE_ID_ERC2981);
    return success;
  }

  function _getRoyaltyInfo(address _nftContractAddress, uint256 _tokenId, uint256 _salePrice)
    private
    view
    returns(address receiverAddress, uint256 royaltyAmount)
  {
    IERC2981 nftContract = IERC2981(_nftContractAddress);
    (address _royaltiesReceiver, uint256 _royalties) = nftContract.royaltyInfo(_tokenId, _salePrice);
    return(_royaltiesReceiver, _royalties);
  }

  /**
   * @dev Create sale item
   * @param _nftContractAddress Collection address
   * @param _tokenId Token id
   * @param _price Item price
   * @param _expiresAt Expiry date
   * @param _saleType Sales type
   */
  function _createItem(
    address _nftContractAddress,
    uint256 _tokenId,
    uint256 _price,
    uint256 _expiresAt,
    SaleType _saleType
  )
    internal
  {
    IERC721 nftRegistry = IERC721(_nftContractAddress);
    address sender = _msgSender();
    address tokenOwner = nftRegistry.ownerOf(_tokenId);

    require(sender == tokenOwner, "Not token owner");
    require(_price > 0, "Price should be bigger than 0");
    require(
      nftRegistry.getApproved(_tokenId) == address(this) || nftRegistry.isApprovedForAll(tokenOwner, address(this)),
      "The contract is not authorized"
    );

    /// charge publication fees
    if (publicationFees[_saleType] > 0 && _publicationFeeWallet != address(0)) {
      uint256 fees = publicationFees[_saleType];
      require(_tokenContract.allowance(sender, address(this)) >= fees, "Insufficient allowance");
      _tokenContract.transferFrom(sender, _publicationFeeWallet, fees);
    }

    bytes32 itemId = keccak256(
      abi.encodePacked(
        block.timestamp,
        tokenOwner,
        _tokenId,
        _nftContractAddress,
        _price,
        _saleType
      )
    );
    
    Item storage item = _items[itemId];

    item.nftAddress = _nftContractAddress;
    item.tokenId = _tokenId;
    item.price = _price;
    item.seller = tokenOwner;
    item.createdAt = block.timestamp;
    item.expiresAt = _expiresAt;
    item.saleType = _saleType;
    item.saleStatus = SaleStatus.Open;

    if (_saleType == SaleType.Auction) {
      _auctionExpiry.push(AuctionExpiry({
        itemId: itemId,
        expiresAt: item.expiresAt,
        executed: false
      }));
    }

    /// hold nft and transfer NFT to this cointract
    nftRegistry.safeTransferFrom(tokenOwner, address(this), _tokenId);
    _holdNFTs[_nftContractAddress][_tokenId] = tokenOwner;

    _itemIndex.push(itemId);

    emit ItemCreated(itemId, _tokenId, tokenOwner, _nftContractAddress, _price, _expiresAt, _saleType);
  }

  /**
   * @dev Required ERC721 implementation
   * @param _nftContractAddress NFT contract(collection) address
   */
  function _requireERC721(address _nftContractAddress) internal view {
    require(_nftContractAddress.isContract(), "Invalid NFT Address");
    require(
      IERC721(_nftContractAddress).supportsInterface(_INTERFACE_ID_ERC721),
      "Unsupported ERC721 Interface"
    );

    bool isExists = false;

    for (uint i = 0; i < _collectionIndex.length; i++) {
      if (_collectionIndex[i] == _nftContractAddress) {
        isExists = true;
        break;
      }
    }

    require(!isExists, "Existance collection");
  }

  /**
   * @dev Check is active collection
   * @param _nftContractAddress NFT contract address
   */
  function _isActiveCollection(address _nftContractAddress) internal view {
    Collection storage collection = collections[_nftContractAddress];
    require(collection.active, "Inactive Collection");
  }

  /**
   * @dev Execute payment
   * @param _itemId Item id
   * @param _sender Sender address
   */
  function _executePayment(
    bytes32 _itemId,
    address _sender
  ) internal virtual {
    Item storage item = _items[_itemId];

    /// validate sale item
    require(item.price > 0, "Item is unavailable");

    uint256 toTransfer = item.price;
    uint256 price = item.price;

    if (item.saleType == SaleType.Auction) {
      require(_holdTokens[_itemId][_sender] >= item.price, "Not enough funds");
      
      for (uint256 i = 0; i < _feeCollectors.length; i++) {
        if (_feeCollectors[i].wallet != address(0) && _feeCollectors[i].percentage > 0) {
          uint256 fees = price.div(1000).mul(_feeCollectors[i].percentage);
          _releaseHoldAmount(_itemId, _sender, _feeCollectors[i].wallet, fees);
          toTransfer -= fees;
        }
      }

      (address royaltiesReceiver, uint256 royalty) = _getRoyaltyInfo(item.nftAddress, item.tokenId, price);

      if (royaltiesReceiver != address(0) && royalty > 0) {
        _releaseHoldAmount(_itemId, _sender, royaltiesReceiver, royalty);
        toTransfer -= royalty;
      }

      require(_tokenContract.balanceOf(address(this)) >= toTransfer, "Transfer to seller failed");
      _releaseHoldAmount(_itemId, _sender, item.seller, toTransfer);
    } else {
      require(_tokenContract.balanceOf(_sender) >= item.price, "Not enough funds");
      require(_tokenContract.allowance(_sender, address(this)) >= price, "Not enough tokens");
      
      _tokenContract.transferFrom(_sender, address(this), price);

      for (uint256 i = 0; i < _feeCollectors.length; i++) {
        if (_feeCollectors[i].wallet != address(0) && _feeCollectors[i].percentage > 0) {
          uint256 fees = price.div(1000).mul(_feeCollectors[i].percentage);
          _tokenContract.transfer(_feeCollectors[i].wallet, fees);
          toTransfer -= fees;
        }
      }

      (address royaltiesReceiver, uint256 royalty) = _getRoyaltyInfo(item.nftAddress, item.tokenId, price);

      if (royaltiesReceiver != address(0) && royalty > 0) {
        _tokenContract.transfer(royaltiesReceiver, royalty);
        toTransfer -= royalty;
      }

      require(_tokenContract.balanceOf(address(this)) >= toTransfer, "Transfer to seller failed");
      _tokenContract.transfer(item.seller, toTransfer);
    }
  }
}
