//SPDX-License-Identifier:MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace_PriceMustBeAboveZer0();
error NftMarketplace_NotApprovedForMarketplace();
error NftMarketplace_AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace_NotOwner();
error NftMarketplace_NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace_PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace_NoProceeds();
error NftMarketplace_TransactionFailed();

contract NftMarketplace is ReentrancyGuard {
    struct Listing {
        uint256 price;
        address seller;
    }
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    //NFT Contract Address=>Nft TokenId->Listing
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    //Seller Address->Amount
    mapping(address => uint256) private s_proceeds;

    ////////////////////
    ////Modifiers///////
    ////////////////////
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace_AlreadyListed(nftAddress, tokenId);
        }
        _;
    }
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketplace_NotOwner();
        }
        _;
    }
    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NftMarketplace_NotListed(nftAddress, tokenId);
        }
        _;
    }

    /////////////////////
    ///Main Functions////
    /////////////////////
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        notListed(nftAddress, tokenId, msg.sender)
        isOwner(nftAddress, tokenId, msg.sender)
    {
        if (price <= 0) {
            revert NftMarketplace_PriceMustBeAboveZer0();
        }
        //1.Send the Nft to the contract .Transfer->Contract hold the NFT
        //2. Owners can still hold the Nft, and give the marketplace approval to sell the
        //Nft for them
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace_NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NftMarketplace_PriceNotMet(nftAddress, tokenId, listedItem.price);
        }
        //We don't just send the money to the seller
        //sending the money to the user❌
        //Have them withdraw the money✅
        s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
        delete (s_listings[nftAddress][tokenId]);
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        //check to make sure the Nft was transferred
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function cancelListing(
        address nftAddress,
        uint256 tokenId
    ) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) external isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender) {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    function withdrawProceeds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NftMarketplace_NoProceeds();
        }
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketplace_TransactionFailed();
        }
    }

    /////////////////////
    ///Getter Functions////
    /////////////////////
    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}
//   1.`listItem`: List NFT's on the marketplace✅
//   2.`buyItem`: Buy the NFT's✅
//   3.`cancelItem`:Cancel a listing✅
//   4.`updateListing`:Update Price
//   5.`withrawProceeds`:Withdraw payments from my bought NFT's
