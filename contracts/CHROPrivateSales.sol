//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Vesting.sol";

/**
 * @title CHRO Private Sales Test
 */
contract CHROPrivateSales is Vesting {
  using SafeMath for uint256;

  event SalesStarted(uint256 amount);
  event SalesStopped(uint256 amount);
  event SalesCreated(address user, uint256 chroAmount, uint256 usdAmount, uint256 chroBalance);
  event WhitelistAdded(address user, uint256 usdAmount);
  event WhitelistRemoved(address user);
  event EmergencyTransfer(address receiver, uint256 amount);

  mapping(address => bool) private _whitelists;
  mapping(address => uint256) private _allocations;

  IERC20 public chroContract;
  IERC20 public usdContract;

  /// token price 1 $CHRO = $0.04
  uint256 public tokenPrice = 40000;

  /// minimum purchase in USD is $500
  uint256 public minimumPurchase = 500000000;
  uint256 public tokensSold;
  bool public isStarted = false;
  address public multisigAddress;
  address public usdTokenAddress;

  /**
   * @notice Sets all required contract addresses
   * @param _chroAddress CHRO contract address
   * @param _usdAddress USD contract address
   * @param _multisigAddress Multisig contract address
   */
  constructor(address _chroAddress, address _usdAddress, address _multisigAddress) Vesting(_chroAddress) {
    chroContract = IERC20(_chroAddress);
    usdContract = IERC20(_usdAddress);
    usdTokenAddress = _usdAddress;
    multisigAddress = payable(_multisigAddress);
  }

  modifier started() {
    require(isStarted, "Private Sales was stopped");
    _;
  }

  /**
   * @notice Check whitelisted status
   * @return bool True or false
   */
  function isWhitelisted(address _user) public view returns(bool) {
    return _whitelists[_user];
  }

  /**
   * @notice Get USD allocation
   * @return uint256 USD amount
   */
  function getAllocation(address _user) public view returns(uint256) {
    return _allocations[_user];
  }

  /**
   * @notice Get token balance
   * @return uint256 Token balance
   */
  function getTokenBalance() public view returns(uint256) {
    return _getTokenBalance();
  }

  /**
   * @notice Buy token directly by buyer
   * @param _usdAmount Amount of USD
   */
  function buyTokens(uint256 _usdAmount) public started {
    uint256 usdAmount = _usdAmount;
    uint256 chroAmount = _usdAmount.div(tokenPrice).mul(1e18);
    
    require(_whitelists[msg.sender], "Not whitelisted");
    require(_usdAmount >= minimumPurchase, "Minimum purchase required");
    require(chroContract.balanceOf(address(this)) >= chroAmount, "Insufficent CHRO allocation");
    require(usdAmount >= _allocations[msg.sender], "Insufficent USD allocation");

    uint256 allowanceOfAmount = usdContract.allowance(msg.sender, address(this));
    require(usdAmount <= allowanceOfAmount, "Insufficent allowance");

    SafeERC20.safeTransferFrom(usdContract, msg.sender, multisigAddress, usdAmount);
    _addBalance(msg.sender, chroAmount);

    tokensSold += chroAmount;

    emit SalesCreated(msg.sender, chroAmount, usdAmount, _getTokenBalance());
  }

  /**
   * ***********************************************
   * The functions below are callable by owner only
   * ***********************************************
   */
  
  /**
   * @notice Start sales
   */
  function startSales() public onlyOwner {
    require(usdTokenAddress != address(0), "Invalid USD token address");
    require(chroContract.balanceOf(address(this)) > 0, "Insufficent funds to start sales");
    
    isStarted = true;
    
    emit SalesStarted(chroContract.balanceOf(address(this)));
  }

  /**
   * @notice Stop sales and transfer balance to the owner
   */
  function stopSales() public onlyOwner {
    isStarted = false;
    emit SalesStopped(_getTokenBalance());
  }

  /**
   * @notice Set USD token address
   * @param _usdTokenAddress The USD token address
   */
  function setUsdTokenAddress(address _usdTokenAddress) public onlyOwner {
    usdTokenAddress = _usdTokenAddress;
    usdContract = IERC20(_usdTokenAddress);
  }

  /**
   * @notice Change multisig address that used to receiving payment
   * @param _multisig Multisig wallet address
   */
  function changeMultisig(address _multisig) public onlyOwner {
    multisigAddress = _multisig;
  }

  /**
   * @notice Change token (CHRO) contract address
   * @param _tokenAddress CHRO contract address
   */
  function changeTokenAddress(address _tokenAddress) public onlyOwner {
    chroContract = IERC20(_tokenAddress);
  }

  /**
   * @notice Add whitelist
   * @param _user User address
   * @param _usdAmount USD amount
   */
  function addWhitelist(address _user, uint256 _usdAmount) public onlyOwner {
    _whitelists[_user] = true;
    _allocations[_user] = _usdAmount;

    emit WhitelistAdded(_user, _usdAmount);
  }

  /**
   * @notice Batch add users
   * @param _users Array of address
   * @param _usdAmounts Array of amounts
   */
  function batchAddWhitelist(address[] memory _users, uint256[] memory _usdAmounts) public onlyOwner {
    require(_users.length > 0, "Invalid inputs");

    for (uint256 i = 0; i < _users.length; i++) {
      _whitelists[_users[i]] = true;
      _allocations[_users[i]] = _usdAmounts[i];

      emit WhitelistAdded(_users[i], _usdAmounts[i]);
    }
  }

  /**
   * @notice Remove whitelist
   * @param _user User address
   */
  function removeWhitelist(address _user) public onlyOwner {
    _whitelists[_user] = false;
    _allocations[_user] = 0;

    emit WhitelistRemoved(_user);
  }

  /**
   * @notice Emergency transfer balance to the owner
   * @param _amount CHRO amount
   */
  function emergencyTransfer(uint256 _amount) public onlyOwner {
    require(_getTokenBalance() >= _amount, "Insufficent balance");
    SafeERC20.safeTransfer(chroContract, owner(), _amount);

    emit EmergencyTransfer(owner(), _amount);
  }

  /**
   * @notice Set token price
   * @param _usdAmount USD price
   */
  function setTokenPrice(uint256 _usdAmount) public onlyOwner {
    tokenPrice = _usdAmount;
  }

  /**
   * @notice Set minimum purchase
   * @param _usdAmount USD price
   */
  function setMinimumPurchase(uint256 _usdAmount) public onlyOwner {
    minimumPurchase = _usdAmount;
  }

  /**
   * ********************************************
   * The functions below are callable internally
   * ********************************************
   */

  /**
   * @notice Get balance of purchasable token
   * @return uint256 Balance of token
   */
  function _getTokenBalance() internal view virtual returns(uint256) {
    uint256 balance = chroContract.balanceOf(address(this));
    return balance.sub(tokensSold);
  }
}