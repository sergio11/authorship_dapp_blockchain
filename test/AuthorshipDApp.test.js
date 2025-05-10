const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("AuthorshipDApp", function () {
    let deployer, creator, admin, user, rewardToken, app;

    // Deploy the required contracts before each test
    beforeEach(async () => {
        // Retrieve the signers for testing (deployer, creator, admin, and user)
        [deployer, creator, admin, user] = await ethers.getSigners();

        // Deploy the RewardToken contract, passing the deployer's address as the initial owner
        const RewardToken = await ethers.getContractFactory("RewardToken");
        rewardToken = await RewardToken.deploy(deployer.address);

        // Deploy the AuthorshipDApp contract, passing the deployer address and reward token address
        const AuthorshipDApp = await ethers.getContractFactory("AuthorshipDApp");
        app = await AuthorshipDApp.deploy(deployer.address, rewardToken.target);

        // Add the creator role to the creator account for testing
        await app.connect(deployer).addCreator(creator.address);

        // Fund the DApp contract with a large amount of tokens for reward distribution
        await rewardToken.transfer(app.target, ethers.parseUnits("100000"));
    });

    it("should allow a creator to register content and receive tokens", async () => {
        const hash = "Qm123";  // The unique identifier (hash) for the content being registered

        // The creator registers content on the DApp
        await app.connect(creator).registerContent(hash);

        // Retrieve the registered content and check that the creator's address is correctly recorded
        const content = await app.getContent(hash);
        expect(content.author).to.equal(creator.address);

        // Verify that the creator received the reward tokens for registering content
        expect(await rewardToken.balanceOf(creator.address)).to.equal(ethers.parseUnits("100"));
    });

    it("should prevent double registration of the same content", async () => {
        const hash = "Qm123";  // The unique identifier (hash) for the content

        // Register content for the first time
        await app.connect(creator).registerContent(hash);

        // Attempt to register the same content again, expecting the operation to revert
        await expect(app.connect(creator).registerContent(hash)).to.be.revertedWith("Content already registered");
    });

    it("should prevent creators from exceeding content limit", async () => {
        // Loop to register 10 pieces of content for the creator
        for (let i = 0; i < 10; i++) {
            await app.connect(creator).registerContent("hash" + i);
        }

        // Attempt to register the 11th content, which should fail because the limit is 10
        await expect(app.connect(creator).registerContent("hash10")).to.be.revertedWith("Max content limit reached");
    });

    it("should allow an admin to approve content", async () => {
        const hash = "QmABC";  // The unique identifier (hash) for the content to be approved

        // The deployer (owner) grants the CREATOR role to the creator account
        await app.connect(deployer).addCreator(creator.address);

        // The deployer (owner) grants the ADMIN role to the admin account
        await app.connect(deployer).assignAdminRole(admin.address);

        // The creator registers the content to be approved
        await app.connect(creator).registerContent(hash);

        // The admin approves the content
        await app.connect(admin).approveContent(hash);

        // Retrieve the content details and check that the status is now 'Approved'
        const content = await app.getContent(hash);
        expect(content.status).to.equal(1); // ContentStatus.Approved
    });


    it("should not allow non-admins to approve content", async () => {
        const hash = "QmDEF";  // The unique identifier (hash) for the content to be approved

        // The deployer (owner) grants the CREATOR role to the creator account
        await app.connect(deployer).addCreator(creator.address);

        // Assign the ADMIN role to the admin address (deployer assigns it in this case)
        await app.connect(deployer).assignAdminRole(admin.address);

        // Register content by the creator
        await app.connect(creator).registerContent(hash);

        // Attempting to approve content by a non-admin user
        // This should revert the transaction with the reason "AccessControl: account"
        await expect(app.connect(creator).approveContent(hash))
            .to.be.reverted;  // Only admin should be able to approve
    });


    it("should allow a creator to update their own content", async () => {
        const oldHash = "QmOld";
        const newHash = "QmNew";

        // Assign creator role explicitly
        await app.connect(deployer).addCreator(creator.address);

        // Register content
        const tx = await app.connect(creator).registerContent(oldHash);
        const initialTimestamp = (await ethers.provider.getBlock(tx.blockNumber)).timestamp;

        // Wait to ensure timestamp change
        await ethers.provider.send("evm_mine");

        // Update content
        const updateTx = await app.connect(creator).updateContent(oldHash, newHash);
        const updatedTimestamp = (await ethers.provider.getBlock(updateTx.blockNumber)).timestamp;

        const content = await app.getContent(newHash);

        expect(content.contentHash).to.equal(newHash);
        expect(content.version).to.equal(2);
        expect(content.author).to.equal(creator.address);
        expect(updatedTimestamp).to.be.greaterThan(initialTimestamp);
    });


    it("should not allow others to update someone else's content", async () => {
        const hash = "QmXYZ"; // Unique identifier for the content to be updated
        const newHash = "NewHash"; // New hash to update the content to

        // Assign CREATOR role to the creator (deployer assigns the role)
        await app.connect(deployer).addCreator(creator.address);
        await app.connect(deployer).addCreator(user.address);

        // Assign ADMIN role to the admin (deployer assigns the role)
        await app.connect(deployer).assignAdminRole(admin.address);

        // Register content by the creator
        await app.connect(creator).registerContent(hash);

        // Ensure the creator can update their own content (valid case)
        await app.connect(creator).updateContent(hash, newHash);
        let content = await app.getContent(newHash);
        expect(content.author).to.equal(creator.address);

        // Attempt to update content by someone who is not the author (should fail)
        await expect(app.connect(user).updateContent(newHash, hash))
            .to.be.revertedWith("Not the author");  // This should be the expected error
    });


    it("should allow owner to set reward and content limit", async () => {
        await app.setRewardAmount(ethers.parseUnits("200"));
        await app.setMaxContentLimit(20);
    });

    it("should emit expected events during registration", async () => {
        const hash = "QmEmit";
        await expect(app.connect(creator).registerContent(hash))
        .to.emit(app, "ContentRegistered")
        .withArgs(creator.address, hash, anyValue)
        .and.to.emit(app, "RewardClaimed");
    });

    it("should not allow a non-creator to register content", async () => {
        const hash = "QmNonCreator";
        await expect(app.connect(user).registerContent(hash)).to.be.revertedWith(
            `Not authorized: Creator role required`
        );
    });

    it("should only allow owner to assign admin role", async () => {
        await expect(app.connect(user).assignAdminRole(user.address)).to.be.reverted;
    });

    it("should not allow approving unregistered content", async () => {
        await app.connect(deployer).assignAdminRole(admin.address);
        await expect(app.connect(admin).approveContent("QmFakeHash")).to.be.revertedWith(
            "Content not registered"
        );
    });

    it("should delete old hash after content update", async () => {
        const oldHash = "QmToDelete";
        const newHash = "QmUpdated";

        await app.connect(creator).registerContent(oldHash);
        await app.connect(creator).updateContent(oldHash, newHash);

        const oldContent = await app.getContent(oldHash);
        expect(oldContent.contentHash).to.equal(""); // Should be empty after delete
    });

    it("should reward the creator with the configured token amount", async () => {
        const customReward = ethers.parseUnits("250");
        await app.connect(deployer).setRewardAmount(customReward);

        const initialBalance = await rewardToken.balanceOf(creator.address);

        await app.connect(creator).registerContent("QmRewardCheck");

        const finalBalance = await rewardToken.balanceOf(creator.address);
        expect(finalBalance - initialBalance).to.equal(customReward);
    });
});