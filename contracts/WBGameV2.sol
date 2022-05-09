// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";

interface IERC721b is IERC721 {
    enum TokenType {
        Wynd,
        Rider,
        Equipment
    }

    function mint(
        address _to,
        TokenType _tokenType,
        string memory _tokenURI
    ) external returns (uint256);
}

contract WBGame is OwnableUpgradeable, ERC721Holder {
    using Strings for uint256;

    enum HolderPlace {
        Unheld,
        DailyActivity,
        Breeding,
        Training,
        Forging
    }

    event TokenMoved(
        address user,
        string productId,
        HolderPlace from,
        HolderPlace to
    );

    event TicketBought(
        address user,
        string productId,
        uint256 price,
        string activity
    );

    event BreedItemCreated(uint256 aParent, uint256 bParent, uint256 child);

    event GameItemTransfer(
        address from,
        address to,
        address collection,
        uint256 tokenId,
        HolderPlace holderPlace
    );

    event GameItemDispatch(
        address from,
        address to,
        address collection,
        uint256 tokenId,
        HolderPlace holderPlace
    );

    event RewardClaimed(address user, uint256 amount, uint256 timestamp);
    event RewardSet(address user, uint256 amount, uint256 timestamp);

    using Counters for Counters.Counter;
    Counters.Counter private breedId;

    struct BreedItem {
        uint256 aParent;
        uint256 bParent;
        uint256 child;
    }

    mapping(uint256 => BreedItem) private _breedItems;
    mapping(uint256 => uint256) private _breedCounts;
    mapping(address => mapping(HolderPlace => uint256[])) private _tokenHolder;
    mapping(address => uint256) private _addressCHROReward;
    mapping(address => uint256) private _addressClaimedTime;

    address private _nftAddress;
    address private _caller;
    uint256 private _breedingCost;
    uint256 private _trainingCost;
    uint256 private _forgingCost;
    uint256 private _totalReward;

    /// first generation or genesis contract
    IERC721 private _aCollection;
    /// next generation (NextGen) contract
    IERC721b private _bCollection;
    /// CHRO contract
    IERC20 private _tokenContract;

    mapping(uint256 => HolderPlace) private _heldTokens;
    mapping(uint256 => address) private _tokenOwners;

    function initialize(
        address _aCollectionAddress,
        address _bCollectionAddress,
        address _tokenAddress
    ) public initializer {
        _transferOwnership(_msgSender());

        _aCollection = IERC721(_aCollectionAddress);
        _bCollection = IERC721b(_bCollectionAddress);
        _tokenContract = IERC20(_tokenAddress);

        _breedingCost = 200000000000000000000;
        _trainingCost = 200000000000000000000;
        _forgingCost = 200000000000000000000;

        breedId = Counters.Counter({_value: 0});
    }

    function buyTicket(
        uint256 _tokenId,
        uint256 _price,
        string memory _activity
    ) public {
        address _collection = address(0);

        if (_tokenId < 20000) {
            _collection = address(_aCollection);
        } else {
            _collection = address(_bCollection);
        }

        require(
            _heldTokens[_tokenId] == HolderPlace.DailyActivity &&
                _tokenOwners[_tokenId] == _msgSender(),
            "Invalid place of token"
        );
        require(
            _tokenContract.balanceOf(_msgSender()) >= _price,
            "Not enough tokens"
        );
        require(
            _tokenContract.allowance(_msgSender(), address(this)) >= _price,
            "Not enough allowance"
        );

        _tokenContract.transferFrom(_msgSender(), address(this), _price);

        emit TicketBought(
            _msgSender(),
            string(
                abi.encodePacked(
                    Strings.toHexString(uint160(_collection), 20),
                    ":",
                    _tokenId.toString()
                )
            ),
            _price,
            _activity
        );
    }

    /**
     * @notice Submit token to this contract and specify the {HolderPlace}
     * @param _holderPlace Holder place
     * @param _tokenId Token ID
     */
    function submit(HolderPlace _holderPlace, uint256 _tokenId) public {
        address _collection = address(0);

        if (_tokenId < 20000) {
            require(
                _aCollection.ownerOf(_tokenId) == _msgSender(),
                "Invalid ownership"
            );
            _aCollection.transferFrom(_msgSender(), address(this), _tokenId);
            _collection = address(_aCollection);
        } else {
            require(
                _bCollection.ownerOf(_tokenId) == _msgSender(),
                "Invalid ownership"
            );
            _bCollection.transferFrom(_msgSender(), address(this), _tokenId);
            _collection = address(_bCollection);
        }

        _heldTokens[_tokenId] = _holderPlace;
        _tokenOwners[_tokenId] = _msgSender();

        // SAVE TO TOKEN HOLDER
        _save(_holderPlace, _tokenId);
        // _tokenHolder[_msgSender()][_holderPlace].push(_tokenId);

        emit GameItemTransfer(
            _msgSender(),
            address(this),
            _collection,
            _tokenId,
            _holderPlace
        );
    }

    /**
     * @notice Batch submit tokens to this contract and specify the {HolderPlace}
     * @param _holderPlace Holder place
     * @param _tokenIds Array of token ids
     */
    function batchSubmit(HolderPlace _holderPlace, uint256[] memory _tokenIds)
        public
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            submit(_holderPlace, _tokenIds[i]);
        }
    }

    /**
     * @notice Dispatch token from this contract
     * @param _holderPlace Holder place
     * @param _tokenId Token ID
     */
    function dispatch(HolderPlace _holderPlace, uint256 _tokenId) internal {
        require(_tokenOwners[_tokenId] == _msgSender(), "Requires own token");
        address _collection = address(0);

        if (_tokenId < 20000) {
            require(
                _aCollection.ownerOf(_tokenId) == address(this),
                "Invalid ownership"
            );
            _aCollection.transferFrom(address(this), _msgSender(), _tokenId);
            _collection = address(_aCollection);
        } else {
            require(
                _bCollection.ownerOf(_tokenId) == address(this),
                "Invalid ownership"
            );
            _bCollection.transferFrom(address(this), _msgSender(), _tokenId);
            _collection = address(_bCollection);
        }

        _remove(_holderPlace, _tokenId);

        emit GameItemDispatch(
            address(this),
            _msgSender(),
            _collection,
            _tokenId,
            _holderPlace
        );
    }

    /**
     * @notice Batch dispatch tokens from this contract and specify the {HolderPlace}
     * @param _holderPlace Holder place
     * @param _tokenIds Array of token ids
     */
    function batchDispatch(HolderPlace _holderPlace, uint256[] memory _tokenIds)
        public
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            dispatch(_holderPlace, _tokenIds[i]);
        }
    }

    /**
     * @notice Library function to remove array element by its value
     * @param _array Array to be manipulated
     * @param _element Element to be removed
     */
    function _removeElement(uint256[] memory _array, uint256 _element)
        internal
        pure
        returns (uint256[] memory)
    {
        for (uint256 i; i < _array.length; i++) {
            if (_array[i] == _element) {
                // TODO FIX:
                delete _array[i];
                break;
            }
        }

        // ERR Member "pop" is not available in uint256[] memory outside of storage.
        return _array;
    }

    /**
     * @notice remove token from tokenHolder
     * @param _holderPlace Holder place
     * @param _tokenId Token id to be removed
     */
    function _remove(HolderPlace _holderPlace, uint256 _tokenId) internal {
        uint256[] memory newArray = _removeElement(
            _tokenHolder[msg.sender][_holderPlace],
            _tokenId
        );
        _tokenHolder[msg.sender][_holderPlace] = newArray;
    }

    /**
     * @notice Save token to tokenHolder
     * @param _holderPlace Holder place
     * @param _tokenId Token id to be saved
     */
    function _save(HolderPlace _holderPlace, uint256 _tokenId) internal {
        _tokenHolder[msg.sender][_holderPlace].push(_tokenId);
    }

    /**
     * @notice View held tokens
     * @param _holderPlace Holder place
     * @param _address Wallet address si user
     * @return array of token_ids
     */
    function idsOf(HolderPlace _holderPlace, address _address)
        public
        view
        returns (uint256[] memory)
    {
        return _tokenHolder[_address][_holderPlace];
    }

    /**
     * @notice Set address mapping to Rewards
     * @param _address Address
     * @param _reward CHRO Reward for address
     */
    function setReward(address _address, uint256 _reward) public {
        _addressCHROReward[_address] = _reward;
        _totalReward += _reward;

        emit RewardSet(_address, _reward, block.timestamp);
    }

    /**
     * @notice Set address mapping to Rewards
     * @param _addresses Addresses
     * @param _rewards CHRO Rewards for address
     */
    function batchSetReward(
        address[] memory _addresses,
        uint256[] memory _rewards
    ) public {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < _addresses.length; i++) {
            totalRewards += _rewards[i];
        }

        require(
            totalRewards <= _tokenContract.balanceOf(address(this)),
            "Insufficent SC Balance"
        );

        for (uint256 i = 0; i < _addresses.length; i++) {
            setReward(_addresses[i], _rewards[i]);
        }
    }

    /**
     * @notice Claim reward
     */
    function claimReward() public {
        require(
            _addressClaimedTime[_msgSender()] + 86400 < block.timestamp,
            "Claim once per day"
        );

        uint256 amount = _addressCHROReward[_msgSender()];

        require(
            amount <= _tokenContract.balanceOf(address(this)),
            "Insufficent SC Balance"
        );

        _tokenContract.transferFrom(address(this), _msgSender(), amount);
        _totalReward -= amount;

        _addressClaimedTime[_msgSender()] = block.timestamp;

        emit RewardClaimed(_msgSender(), amount, block.timestamp);
    }

    /**
     ***************************************************************************************
     *************************************** BREEDING **************************************
     ***************************************************************************************
     */
    function breed(uint256[] memory _parents, string memory _tokenURI) public {
        require(_parents.length == 2, "Requires 2 wynds");
        require(_parents[0] != _parents[1], "Identical tokens");

        for (uint256 i = 0; i < 2; i++) {
            /// both sould be held by Breeding and owned by sender
            require(
                _heldTokens[_parents[i]] == HolderPlace.Breeding &&
                    _tokenOwners[_parents[i]] == _msgSender(),
                "Invalid place of token"
            );

            /// maximum breed of each token
            require(_breedCounts[_parents[i]] < 3, "Max breed count of parent");
        }

        /// check balance
        require(
            _tokenContract.balanceOf(_msgSender()) >= _breedingCost,
            "Not enough tokens"
        );
        require(
            _tokenContract.allowance(_msgSender(), address(this)) >=
                _breedingCost,
            "Not enough allowance"
        );

        /// transfer CHRO to this contract as P2E wallet
        _tokenContract.transferFrom(_msgSender(), address(this), _breedingCost);

        /// mint to NextGen collection
        uint256 childId = _bCollection.mint(
            _msgSender(),
            IERC721b.TokenType.Wynd,
            _tokenURI
        );

        breedId.increment();
        uint256 id = breedId.current();

        _breedItems[id] = BreedItem({
            aParent: _parents[0],
            bParent: _parents[1],
            child: childId
        });

        _breedCounts[_parents[0]] += 1;
        _breedCounts[_parents[1]] += 1;

        emit BreedItemCreated(_parents[0], _parents[1], childId);
    }

    /**
     * @notice Get breed count of the given token id
     * @param _tokenId Token id
     */
    function breedCountOf(uint256 _tokenId) public view returns (uint256) {
        return _breedCounts[_tokenId];
    }

    function move(
        uint256 _tokenId,
        HolderPlace _from,
        HolderPlace _to
    ) public {
        require(
            _heldTokens[_tokenId] == _from &&
                _tokenOwners[_tokenId] == _msgSender(),
            "Invalid source of token"
        );

        address _collection = address(0);

        if (_tokenId < 20000) {
            _collection = address(_aCollection);
        } else {
            _collection = address(_bCollection);
        }

        _heldTokens[_tokenId] = _to;

        // TRANSFER TOKEN HOLDS
        _save(_to, _tokenId);
        _remove(_from, _tokenId);

        emit TokenMoved(
            _msgSender(),
            string(
                abi.encodePacked(
                    Strings.toHexString(uint160(_collection), 20),
                    ":",
                    _tokenId.toString()
                )
            ),
            _from,
            _to
        );
    }

    function batchMove(
        uint256[] memory _tokenIds,
        HolderPlace _from,
        HolderPlace _to
    ) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            move(_tokenIds[i], _from, _to);
        }
    }
}
