// contracts/EczodexUSD.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EczodexUSD is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable
{
    mapping(address => address) private _minterDesignations;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    bytes32 public constant DEBT_CEILING_ADJUSTER_ROLE =
        keccak256("DEBT_CEILING_ADJUSTER_ROLE");

    uint public debtCeiling;
    mapping(address => bool) public isBlacklisted;

    event Minted(address indexed minter, uint256 amount);
    event Burned(address indexed burner, uint256 amount);
    event DebtCeilingAdjusted(address indexed adjuster, uint256 newDebtCeiling);
    event Blacklisted(address indexed account);
    event Unblacklisted(address indexed account);
    event BlacklistedTransferAttempt(
        address indexed from,
        address indexed to,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function hasRole(
        bytes32 role,
        address account
    ) public view override returns (bool) {
        return super.hasRole(role, account);
    }

    function initialize() public initializer {
        __ERC20_init("Eczodex USD CDP Stablecoin", "USDE");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("Eczodex USD Stablecoin");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(BLACKLISTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(DEBT_CEILING_ADJUSTER_ROLE, msg.sender);
    }

    function blacklist(address account) public onlyRole(BLACKLISTER_ROLE) {
        if (!isBlacklisted[account]) {
            isBlacklisted[account] = true;
            emit Blacklisted(account);
        }
    }

    function removeFromBlacklist(
        address account
    ) public onlyRole(BLACKLISTER_ROLE) {
        if (isBlacklisted[account]) {
            isBlacklisted[account] = false;
            emit Unblacklisted(account);
        }
    }

    function setDebtCeiling(
        uint256 newDebtCeiling
    ) public onlyRole(DEBT_CEILING_ADJUSTER_ROLE) {
        if (debtCeiling != newDebtCeiling) {
            debtCeiling = newDebtCeiling;
            emit DebtCeilingAdjusted(msg.sender, debtCeiling);
        }
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
        emit Paused(msg.sender);
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
        emit Unpaused(msg.sender);
    }

    function setMinterDesignation(
        address designatedAddress
    ) public onlyRole(MINTER_ROLE) {
        _minterDesignations[msg.sender] = designatedAddress;
    }

    function mint(uint256 amount) public onlyRole(MINTER_ROLE) {
        require(
            debtCeiling >= totalSupply() + amount,
            "Minting would exceed the debt ceiling"
        );
        address designatedMinter = _minterDesignations[msg.sender];
        _mint(designatedMinter, amount);
        emit Minted(msg.sender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        if (isBlacklisted[from] || isBlacklisted[to]) {
            emit BlacklistedTransferAttempt(from, to, amount);
            revert("Either sender or receiver is blacklisted");
        }

        super._beforeTokenTransfer(from, to, amount);
    }

    function burnTokens(
        address account,
        uint256 amount
    ) public onlyRole(BURNER_ROLE) {
        _burn(account, amount);
    }

    function _burn(
        address account,
        uint256 amount
    ) internal override onlyRole(BURNER_ROLE) {
        super._burn(account, amount);
        emit Burned(account, amount);
    }
}
