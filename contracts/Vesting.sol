//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

/**
 * @title CHRO Vesting handler
 * @dev Inspired by OpenZeppelin Contracts v4.4.1 (finance/VestingWallet.sol)
 */
contract Vesting is Ownable {
  using SafeMath for uint256;

  event BalanceAdded(address beneficiary, uint256 amount);
  event TokenReleased(address beneficiary, uint256 amount);
  event PeriodUpdated(address owner, uint256 start, uint256 period, uint256 divider);

  /// CHRO contract address
  IERC20 public chroToken;

  uint256 private _start;
  uint256 private _duration;
  uint256 private _divider = 4;

  struct Account {
    uint256 balance;
    uint256 released;
  }

  mapping(address => Account) private _accounts;
  mapping(uint => uint256) public releaseSchedule;

  uint256 private _balance;
  uint256 private _released;

  constructor(address _chroToken) {
    chroToken = IERC20(_chroToken);
  }

  /**
   * @notice Get start timestamp
   * @return _start Start timestamp
   */
  function start() public view virtual returns (uint256) {
    return _start;
  }

  /**
   * @notice Get duration
   * @return _duration Duration in seconds
   */
  function duration() public view virtual returns (uint256) {
    return _duration;
  }

  /**
   * @notice Get divider
   * @return _divider Divider
   */
  function divider() public view virtual returns (uint256) {
    return _divider;
  }

  /**
   * @notice Get total of token balance
   * @return _balance Balance of token
   */
  function getBalance() public view virtual returns (uint256) {
    return _balance;
  }

  /**
   * @notice Get total of released token
   * @return _released Released token
   */
  function getReleased() public view virtual returns (uint256) {
    return _released;
  }

  /**
   * @notice Get user account
   * @param _user User address
   * @return Account User vested balance
   */
  function getAccount(address _user) public view returns(Account memory) {
    Account storage account = _accounts[_user];
    return account;
  }

  /**
   * @notice Release token to the user
   */
  function release() public {
    uint256 lockTimestamp = _getLockTimestamp(block.timestamp);
    require(lockTimestamp > 0, "Can't release CHRO");
    Account storage account = _accounts[msg.sender];

    uint256 _vestedAmount = _vestingSchedule(account.balance, lockTimestamp);
    uint256 toRelease = _vestedAmount.sub(account.released);

    require(toRelease > 0, "CHRO has been claimed");
    
    if (toRelease > 0) {
      SafeERC20.safeTransfer(chroToken, msg.sender, toRelease);
      account.released += toRelease;

      _released += toRelease;
      _balance -= toRelease;

      emit TokenReleased(msg.sender, toRelease);
    }
  }

  /**
   * @notice Get vested amount
   * @param _user User address
   * @param _timestamp Timestamp
   * @return uint256 Vested amount of the user
   */
  function vestedAmount(
    address _user,
    uint256 _timestamp
  ) public view virtual returns (uint256) {
    Account storage account = _accounts[_user];
    return _vestingSchedule(account.balance.add(account.released), _timestamp);
  }

  /**
   * *************************************************************
   * The functions below are callable internally by this contract
   * *************************************************************
   */

  /**
   * @notice Add balance to the user account
   * @param _user User address
   * @param _amount Amount of token
   */
  function _addBalance(address _user, uint256 _amount) internal virtual {
    _accounts[_user].balance += _amount;
    _balance += _amount;

    emit BalanceAdded(_user, _amount);
  }

  /**
   * @dev Virtual implementation of the vesting formula.
   * @dev This returns the amout vested, as a function of time, for an asset given its total historical allocation.
   */
  function _vestingSchedule(
    uint256 _allocationTotal,
    uint256 _timestamp
  ) internal view virtual returns (uint256) {
    if (_timestamp < start()) {
      return 0;
    } else if (_timestamp > start().add(duration())) {
      return _allocationTotal;
    } else {
      return _allocationTotal.mul(_timestamp.sub(start())).div(duration());
    }
  }

  /**
   * @notice Get locked timestamp
   * @param _timestamp Given timestamp
   * @return lockTimestamp Locked timestamp
   */
  function _getLockTimestamp(uint256 _timestamp) internal view virtual returns (uint256) {
    uint256 durationPerDivider = duration().div(_divider);
    uint256 lastTime = start().add(duration()).add(durationPerDivider);
    uint256 lockTimestamp = 0;

    for (uint256 i = _divider; i > 0; i--) {
      lastTime -= durationPerDivider;
      if (lastTime <= _timestamp) {
        lockTimestamp = lastTime;
        break;
      }
    }

    return lockTimestamp;
  }

  /**
   * @dev Sets release schedule
   */
  function _setReleaseSchedule() internal virtual {
    uint256 durationPerDivider = duration().div(_divider);

    for (uint256 i = 0; i < _divider; i++) {
      releaseSchedule[i] = start().add(durationPerDivider);
    }
  }

  /**
   * ***********************************************
   * The functions below are callable by owner only
   * ***********************************************
   */
   
  /**
   * @notice Set vesting period
   * @param _startTimestamp Timestamp of start
   * @param _durationSeconds Duration in seconds
   * @param _dividerCount Divider count
   */
  function setPeriod(uint256 _startTimestamp, uint256 _durationSeconds, uint256 _dividerCount) public onlyOwner {
    _start = _startTimestamp;
    _duration = _durationSeconds;
    _divider = _dividerCount;

    _setReleaseSchedule();

    emit PeriodUpdated(owner(), _startTimestamp, _durationSeconds, _dividerCount);
  }
}