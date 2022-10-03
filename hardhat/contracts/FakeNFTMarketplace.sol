// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FakeNFTMarketplace {
    //need a mapping of TokenId => Owner addresses
    mapping(uint256 => address) public tokens;
    // ether price for each NFT;
    uint256 nftPrice = 0.1 ether;

    //this function accepts the eth and set msg.sender as the owner of the NFT
    function purchase(uint256 _tokenId) public payable {
        require(msg.value == nftPrice, "The price is 0.1 ether");
        tokens[_tokenId] = msg.sender;
    }

    function getPrice() public view returns (uint256) {
        return nftPrice;
    }

    //this function checks if the NFT of id: _tokenId is available to buy
    function available(uint256 _tokenId) public view returns (bool) {
        if (tokens[_tokenId] == address(0)) {
            return true;
        }
        return false;
    }
}
