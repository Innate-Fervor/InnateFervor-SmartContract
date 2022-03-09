// Market contract
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Market is Ownable, ERC721Holder {
    using SafeMath for uint256;
	
	uint256 constant public PERCENTS_DIVIDER = 1000;
	uint256 public feeAdmin = 25; // 2.5% fee
	address public adminAddress;

    /* Pairs to swap NFT _id => price */
	struct Pair {
		uint256 pair_id;
		address collection;
		uint256 token_id;
		address owner;
		uint256 price;
        bool bValid;		
	}

	address[] public collections;
	// collection address => creator address

	// token id => Pair mapping
    mapping(uint256 => Pair) public pairs;
	uint256 public currentPairId;
    
	uint256 public totalEarning; /* Total earning */
	uint256 public totalSwapped; /* Total swap count */

	/** Events */
    event ItemListed(uint256 id, address collection, uint256 token_id, uint256 price, address owner);
	event ItemDelisted(uint256 id);
    event Swapped(address buyer, Pair pair);

	constructor (address _adminAddress) {	
		adminAddress = _adminAddress;
	}  

	function setFee(uint256 _feeAdmin, 
		address _adminAddress) external onlyOwner {
		feeAdmin = _feeAdmin;
		adminAddress = _adminAddress;	
	}

    function list(address _collection, uint256 _token_id, uint256 _price) OnlyItemOwner(_collection,_token_id) public {
		require(_price > 0, "invalid price");		

		IERC721 nft = IERC721(_collection);        
        nft.safeTransferFrom(msg.sender, address(this), _token_id);

		currentPairId = currentPairId.add(1);

		pairs[currentPairId].pair_id = currentPairId;
		pairs[currentPairId].collection = _collection;
		pairs[currentPairId].token_id = _token_id;
		pairs[currentPairId].owner = msg.sender;		
		pairs[currentPairId].price = _price;	
        pairs[currentPairId].bValid = true;	

        emit ItemListed(currentPairId, 
			_collection,
			_token_id, 
			_price, 
			msg.sender			
		);
    }

    function delist(uint256 _id) external {        
        require(pairs[_id].bValid, "not exist");

        require(msg.sender == pairs[_id].owner || msg.sender == owner(), "Error, you are not the owner");        
        IERC721(pairs[_id].collection).safeTransferFrom(address(this), pairs[_id].owner, pairs[_id].token_id);        
        pairs[_id].bValid = false;
        emit ItemDelisted(_id);        
    }


    function buy(uint256 _id) external payable {
		require(_id <= currentPairId && pairs[_id].pair_id == _id, "Could not find item");
        require(pairs[_id].bValid, "invalid Pair id");
		require(pairs[_id].owner != msg.sender, "owner can not buy");

		Pair memory pair = pairs[_id];
		uint256 totalAmount = pair.price;
		require(msg.value >= totalAmount, "insufficient balance");

		// transfer coin to feeAdmin
		if (feeAdmin > 0){
			payable(adminAddress).transfer(totalAmount.mul(feeAdmin).div(PERCENTS_DIVIDER));
		}
		

		// transfer coin to owner
		uint256 ownerPercent = PERCENTS_DIVIDER.sub(feeAdmin);
		payable(pair.owner).transfer(totalAmount.mul(ownerPercent).div(PERCENTS_DIVIDER));		
		
		// transfer NFT token to buyer
		IERC721(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
		
		pairs[_id].bValid = false;

		totalEarning = totalEarning.add(totalAmount);
		totalSwapped = totalSwapped.add(1);

        emit Swapped(msg.sender, pair);		
    }

	function withdrawCoin() public onlyOwner {
		uint balance = address(this).balance;
		require(balance > 0, "insufficient balance");
		payable(msg.sender).transfer(balance);
	}

	modifier OnlyItemOwner(address tokenAddress, uint256 tokenId){
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender);
        _;
    }    
}
