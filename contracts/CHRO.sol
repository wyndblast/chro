//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Chronicum Token
 * @author WyndBlast Development Team
 */
contract CHRO is ERC20, ERC20Permit, ERC20Votes, ERC20Pausable, Ownable {
  /// Maximum supply 300,000,000
  uint256 private constant MAX_SUPPLY = 300000000000000000000000000;

  /**
   * Constuctor
   */
  constructor() ERC20("Chronicum", "CHRO") ERC20Permit("Chronicum") {}

  /**
   * @notice Destroys amount tokens from account
   * @param _amount Amount of token
   */
  
  function burn(uint256 amount) public onlyOwner returns (bool) {
    _burn(_msgSender(), amount);
    return true;
  }
  /**
   * @notice Mint token
   * @param _to Receiver address
   * @param _amount Token amount
   */
  function mint(
    address _to,
    uint256 _amount
  ) public onlyOwner {
    require(_to != address(0), "Not Mint for the zero address");
    require(totalSupply() + _amount <= MAX_SUPPLY, "Exceeded maximum supply");
    _mint(_to, _amount);
  }

  /**
   * @notice Pause
   */
  function pause() public onlyOwner {
    _pause();
  }
  
  /**
   * @notice Unpause
   */
  function unpause() public onlyOwner {
    _unpause();
  }

  /**
   * *******************************************************
   * The functions below are overrides required by Solidity.
   * *******************************************************
   */

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal
    virtual
    override(ERC20, ERC20Pausable) {
    super._beforeTokenTransfer(from, to, amount);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal
    override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function _mint(
    address to,
    uint256 amount
  ) internal
    override(ERC20, ERC20Votes) {
    super._mint(to, amount);
  }
  
  function _burn(
    address account,
    uint256 amount
  ) internal
    override (ERC20, ERC20Votes) {
    super._burn(account, amount);
  }
}