// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./RewardToken.sol";
import "./IAuthorshipDApp.sol";

/**
 * @title AuthorshipDApp
 * @dev A decentralized application for content registration, approval, and reward distribution.
 *      This contract allows creators to register content, receive rewards in tokens, and manage
 *      the content's approval status. Only administrators can approve content, and only creators
 *      can register or update their own content.
 */
contract AuthorshipDApp is IAuthorshipDApp, Ownable, AccessControl, ReentrancyGuard {
    // Define roles using AccessControl
    bytes32 private constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping to store registered content by content hash
    mapping(string => Content) private _contents;

    // Reward token contract instance
    RewardToken private _erc20RewardToken;
    uint256 private _rewardAmount = 100 * 10**18; // Reward for each registered content (100 ART tokens)
    
    // Content limits per creator
    uint256 private _maxContentPerCreator = 10;
    mapping(address => uint256) private _contentCount;

    /**
    * @dev Constructor for the AuthorshipDApp contract.
    *      Initializes the contract by assigning ownership, setting up access roles, and
    *      defining the reward token contract.
    *
    * @param initialOwner The address that will be granted contract ownership and all admin/creator roles.
    * @param _rewardToken The address of the deployed ERC20-compatible reward token (e.g., RewardToken).
    *
    * Requirements:
    * - `initialOwner` will be granted `DEFAULT_ADMIN_ROLE`, `ADMIN_ROLE`, and `CREATOR_ROLE`.
    * - The ownership of the contract (`Ownable`) will also be transferred to `initialOwner`.
    * - The reward token must already be deployed and conform to the expected interface.
    */
    constructor(address initialOwner, address _rewardToken) Ownable(initialOwner) {
        // Grant all essential roles to the initial owner
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _grantRole(CREATOR_ROLE, initialOwner);
        _grantRole(ADMIN_ROLE, initialOwner);

        // Set the reward token contract
        _erc20RewardToken = RewardToken(_rewardToken);
    }


    /**
     * @dev Modifier to restrict actions to creators only.
     */
    modifier onlyCreator() {
        require(hasRole(CREATOR_ROLE, msg.sender), "Not authorized: Creator role required");
        _;
    }

    /**
     * @dev Registers new content to the platform and rewards the creator with tokens.
     *      Emits `ContentRegistered` and `RewardClaimed` events.
     * @param contentHash The unique identifier (hash) for the content.
     */
    function registerContent(string memory contentHash) external override onlyCreator nonReentrant {
        require(_contentCount[msg.sender] < _maxContentPerCreator, "Max content limit reached");
        require(bytes(_contents[contentHash].contentHash).length == 0, "Content already registered");

        // Register new content
        _contents[contentHash] = Content({
            author: msg.sender,
            contentHash: contentHash,
            timestamp: block.timestamp,
            version: 1,
            status: ContentStatus.Pending
        });

        // Increment the content count for the creator
        _contentCount[msg.sender]++;

        // Emit the content registered event
        emit ContentRegistered(msg.sender, contentHash, block.timestamp);

        // Transfer the reward tokens to the creator
        _erc20RewardToken.transfer(msg.sender, _rewardAmount);
        emit RewardClaimed(msg.sender, _rewardAmount);
    }

    /**
     * @dev Approves content by an administrator, changing its status to `Approved`.
     *      Emits `ContentApproved` event.
     * @param contentHash The unique identifier (hash) for the content.
     */
    function approveContent(string memory contentHash) external override onlyRole(ADMIN_ROLE) nonReentrant {
        require(bytes(_contents[contentHash].contentHash).length != 0, "Content not registered");
        
        Content storage content = _contents[contentHash];
        content.status = ContentStatus.Approved;

        // Emit the content approved event
        emit ContentApproved(contentHash, block.timestamp);
    }

    /**
     * @dev Updates content registered by a creator, allowing them to change the content hash.
     *      The content version is incremented.
     *      Emits `ContentUpdated` event.
     * @param contentHash The unique identifier (hash) for the existing content.
     * @param newContentHash The new unique identifier (hash) for the updated content.
     */
    function updateContent(string memory contentHash, string memory newContentHash) external override onlyCreator nonReentrant {
        require(bytes(_contents[contentHash].contentHash).length != 0, "Content not registered");
        require(_contents[contentHash].author == msg.sender, "Not the author");

        // Increment version for the updated content
        Content memory updatedContent = _contents[contentHash]; // Store the existing content temporarily
        updatedContent.version++;
        updatedContent.contentHash = newContentHash;
        updatedContent.timestamp = block.timestamp;
        
        // Delete the old content entry from the mapping
        delete _contents[contentHash];

        // Store the updated content under the new content hash
        _contents[newContentHash] = updatedContent;

        // Emit the content updated event
        emit ContentUpdated(msg.sender, newContentHash, block.timestamp);
    }

    /**
     * @dev Adds a new creator to the platform (only the owner can do this).
     *      Emits `CreatorAdded` event.
     * @param newCreator The address of the new creator.
     */
    function addCreator(address newCreator) external override onlyOwner {
        grantRole(CREATOR_ROLE, newCreator);
        emit CreatorAdded(newCreator);
    }

    /**
     * @dev Removes a creator from the platform (only the owner can do this).
     *      Emits `CreatorRemoved` event.
     * @param creator The address of the creator to remove.
     */
    function removeCreator(address creator) external override onlyOwner {
        revokeRole(CREATOR_ROLE, creator);
        emit CreatorRemoved(creator);
    }

    /**
     * @dev Sets the reward amount for content registration (only the owner can do this).
     * @param newRewardAmount The new reward amount (in token units).
     */
    function setRewardAmount(uint256 newRewardAmount) external override onlyOwner {
        _rewardAmount = newRewardAmount;
    }

    /**
    * @dev Assigns the admin role to a specified address. 
    *      Only the contract owner can execute this function.
    *      This allows the designated address to perform administrative tasks on the platform.
    *      The `AdminAdded` event is emitted when the role is assigned.
    *
    * @param account The address to be assigned the admin role.
    */
    function assignAdminRole(address account) external override onlyOwner {
        grantRole(ADMIN_ROLE, account);
        emit AdminAdded(account);
    }

    /**
    * @dev Revokes the admin role from a specified address. 
    *      Only the contract owner can execute this function.
    *      This removes the administrative privileges from the specified address.
    *      The `AdminRemoved` event is emitted when the role is revoked.
    *
    * @param account The address from which the admin role will be revoked.
    */
    function revokeAdminRole(address account) external override onlyOwner {
        revokeRole(ADMIN_ROLE, account);
        emit AdminRemoved(account);
    }

    /**
     * @dev Sets the maximum content registration limit per creator (only the owner can do this).
     * @param newLimit The new maximum content registration limit.
     */
    function setMaxContentLimit(uint256 newLimit) external override onlyOwner {
        _maxContentPerCreator = newLimit;
    }

    /**
     * @dev Returns the details of a registered content by its content hash.
     * @param contentHash The unique identifier (hash) for the content.
     * @return The details of the content (author, hash, timestamp, version, status).
     */
    function getContent(string memory contentHash) external override view returns (Content memory) {
        return _contents[contentHash];
    }
}