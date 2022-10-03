// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for FakeNFTMarketplace
interface IFakeNFTMarketplace {
    //getPrice() returns the price in WEI of an NFT in the Marketplace
    function getPrice() external view returns (uint256);

    //available() returns boolean depending if a given _tokenId NFT as been sold already
    function available(uint256 _tokenId) external view returns (bool);

    //purchase() purchase a given _tokenId NFT in the Marketplace
    function purchase(uint256 _tokenId) external payable;
}

// Interface for CryptoDevsNFT
interface ICryptoDevsNFT {
    //balanceOf() returns how many NFTs an address owns
    function balanceOf(address _owner) external view returns (uint256);

    //tokenOfOwnerByIndex() returns a tokenId of a given index for owner
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    //proposal struct will contain all important information for each proposal
    struct Proposal {
        //tokenId of the NFT to purchase if proposal passes
        uint256 nftTokenId;
        //deadline is the max time to the proposal to be active
        uint256 deadline;
        //yayVotes is the amount of positive votes
        uint256 yayVotes;
        //nayVotes is the amount of negative votes
        uint256 nayVotes;
        //executed represents if the proposal has been executed
        bool executed;
        //this mapping indicates if an NFT has already casted his vote
        mapping(uint256 => bool) voters;
    }

    //this mapping will contain all proposals
    mapping(uint256 => Proposal) public proposals;
    //number of proposals created
    uint256 public numProposals;
    //enum so the vote only has two possible values
    enum Vote {
        YAY,
        NAY
    }

    IFakeNFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    //constructor initialize contract variables, accepting eth for the DAO treasury
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    //this modifier will limit the use of certain functions for NFT Holders only
    modifier nftHolderOnly() {
        require(
            cryptoDevsNFT.balanceOf(msg.sender) > 0,
            "Only NFT Holders can use this"
        );
        _;
    }
    //this modifier is for when the proposal is active and not have its deadline exceded
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "Deadline exceeded"
        );
        _;
    }
    //this modifier will execute a proposal which deadline has exceeded
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "Deadline not exceeded"
        );
        require(
            proposals[proposalIndex].executed == false,
            "Proposal already executed"
        );
        _;
    }

    //createProposal allow holders to create proposals in the DAO
    function createProposal(uint256 _nftTokenId)
        external
        nftHolderOnly
        returns (uint256)
    {
        require(nftMarketplace.available(_nftTokenId), "NFT not available");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        //set proposal deadline for 5min after creation
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return (numProposals - 1);
    }

    //voteOnProposal allow NFT holders to vote on a active proposal
    function voteOnProposal(uint256 _proposalIndex, Vote vote)
        external
        nftHolderOnly
        activeProposalOnly(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];
        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        //calculates how many votes this holder can make
        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        //check if the Holder have available votes
        require(numVotes > 0, "You have already voted");

        //submit the votes
        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    //executeProposal will shut down a proposal
    function executeProposal(uint256 _proposalIndex)
        external
        nftHolderOnly
        inactiveProposalOnly(_proposalIndex)
    {
        Proposal storage proposal = proposals[_proposalIndex];

        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "Not enough balance");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    //withdrawEther will allow contract owner to withdraw ETH from the DAO if needed
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    //this functions allow the contract to accept ETH directly
    receive() external payable {}

    fallback() external payable {}
}
