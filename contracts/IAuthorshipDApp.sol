// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAuthorshipDApp {
    
    // Enum representing the possible content statuses
    enum ContentStatus { Pending, Approved, Rejected }

    // Struct representing the content registered by a creator
    struct Content {
        address author;        // The creator's address
        string contentHash;    // The hash of the content (e.g., a file hash or content identifier)
        uint256 timestamp;     // The timestamp when the content was registered
        uint256 version;       // The version of the content
        ContentStatus status;  // The current status of the content (Pending, Approved, Rejected)
    }

    // --- Public Methods ---

    /**
     * @dev Registers new content to the blockchain and rewards the creator with tokens.
     * Emits a `ContentRegistered` event and transfers reward tokens to the creator.
     * @param contentHash The unique identifier (hash) for the content.
     */
    function registerContent(string memory contentHash) external;

    /**
     * @dev Allows an admin to approve a content registration.
     * Emits a `ContentApproved` event once the content is approved.
     * @param contentHash The unique identifier (hash) for the content.
     */
    function approveContent(string memory contentHash) external;

    /**
     * @dev Allows the creator to update the content they have registered.
     * The content version will be incremented.
     * Emits a `ContentUpdated` event after the update.
     * @param contentHash The unique identifier (hash) for the old content.
     * @param newContentHash The new unique identifier (hash) for the updated content.
     */
    function updateContent(string memory contentHash, string memory newContentHash) external;

    /**
     * @dev Adds a new creator to the platform. Only the owner can call this.
     * Emits a `CreatorAdded` event once a new creator is added.
     * @param newCreator The address of the new creator to be added.
     */
    function addCreator(address newCreator) external;

    /**
     * @dev Removes an existing creator from the platform. Only the owner can call this.
     * Emits a `CreatorRemoved` event once the creator is removed.
     * @param creator The address of the creator to be removed.
     */
    function removeCreator(address creator) external;

    /**
     * @dev Sets the reward amount that will be given to creators for registering content.
     * Only the owner can call this.
     * @param newRewardAmount The new reward amount (in token units) for content registration.
     */
    function setRewardAmount(uint256 newRewardAmount) external;

    /**
     * @dev Sets the maximum number of contents a creator can register.
     * Only the owner can call this.
     * @param newLimit The new content limit for each creator.
     */
    function setMaxContentLimit(uint256 newLimit) external;

    /**
     * @dev Returns the details of a content by its content hash.
     * @param contentHash The unique identifier (hash) for the content.
     * @return The content details (author, hash, timestamp, version, status).
     */
    function getContent(string memory contentHash) external view returns (Content memory);
    
    // --- Public Events ---

    /**
     * @dev Emitted when new content is registered by a creator.
     * @param author The address of the content creator.
     * @param contentHash The unique identifier (hash) for the content.
     * @param timestamp The timestamp of content registration.
     */
    event ContentRegistered(address indexed author, string contentHash, uint256 timestamp);

    /**
     * @dev Emitted when content is approved by an admin.
     * @param contentHash The unique identifier (hash) for the approved content.
     * @param timestamp The timestamp of content approval.
     */
    event ContentApproved(string contentHash, uint256 timestamp);

    /**
     * @dev Emitted when content is updated by its creator.
     * @param author The address of the content creator.
     * @param newContentHash The new unique identifier (hash) for the updated content.
     * @param timestamp The timestamp of the content update.
     */
    event ContentUpdated(address indexed author, string newContentHash, uint256 timestamp);

    /**
     * @dev Emitted when a new creator is added to the platform.
     * @param newCreator The address of the new creator added.
     */
    event CreatorAdded(address indexed newCreator);

    /**
     * @dev Emitted when a creator is removed from the platform.
     * @param creator The address of the creator removed.
     */
    event CreatorRemoved(address indexed creator);

    /**
     * @dev Emitted when a creator claims their reward for registering content.
     * @param creator The address of the content creator receiving the reward.
     * @param amount The amount of reward tokens transferred.
     */
    event RewardClaimed(address indexed creator, uint256 amount);
}