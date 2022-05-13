// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract NFT {
    struct nft {
        uint256 id;
        string name;
        uint256 price;
        address owner;
        bool isForSale;
    }
    struct nftBidding {
        uint256 higgestAmount;
        address higgestBidder;
        uint256 biddersCount;
        mapping(address => uint256) biddingAmount;
        address[] bidders;
    }
    mapping(uint256 => nft) minted;
    mapping(address => uint256[]) addressToNFTID;
    uint256[] forSale;
    uint256 index = 0;
    mapping(uint256 => nftBidding) public bids;
    //  a person bidded to which nft
    mapping(address => uint256[]) biddedOn;

    constructor() {}

    event nftMinted(address indexed by, uint256 nftId);
    event nftDeleted(address indexed by, uint256 nftId);
    event ownershipTransfer(
        address indexed from,
        address indexed to,
        uint256 nftID
    );
    event withDrawFromBidding(
        address indexed who,
        uint256 indexed from,
        uint256 amount
    );
    event biddingResult(
        uint256 biddingAmount,
        uint256 indexed nftId,
        address indexed transferFrom,
        address indexed transferTo
    );
    modifier onlyOwner(uint256 _id) {
        require(_id < index, "nft not found");
        require(msg.sender == minted[_id].owner, "you are not owner");
        _;
    }

    function removeElementFromUintArray(uint256[] storage array, uint256 ele)
        internal
    {
        uint256 idx = array.length;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == ele) {
                idx = i;
                break;
            }
        }
        require(idx < array.length, "element not found in array");
        array[idx] = array[array.length - 1];
        array.pop();
    }

    function removeElementFromAddresstArray(
        address[] storage array,
        address ele
    ) internal {
        uint256 idx = array.length;
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == ele) {
                idx = i;
                break;
            }
        }
        require(idx < array.length, "element not found in array");
        array[idx] = array[array.length - 1];
        array.pop();
    }

    function mint(string memory _name, uint256 _price) public {
        nft storage newNFT = minted[index];
        newNFT.id = index;
        newNFT.price = _price;
        newNFT.owner = msg.sender;
        newNFT.name = _name;
        emit nftMinted(msg.sender, index);
        addressToNFTID[msg.sender].push(index);
        index++;
    }

    function updateName(uint256 _id, string memory _name)
        public
        onlyOwner(_id)
    {
        require(!minted[_id].isForSale, "nft is for sale");
        minted[_id].name = _name;
    }

    function updatePrice(uint256 _id, uint256 _price) public onlyOwner(_id) {
        require(!minted[_id].isForSale, "nft is for sale");
        minted[_id].price = _price;
        // can create event for update price if needed
    }

    // get nft with nft's id
    function getNFT(uint256 _id) public view returns (nft memory) {
        require(_id < index, "nft not found");
        return minted[_id];
    }

    // nft with are for sale
    function nftForBidding() public view returns (uint256[] memory) {
        return forSale;
    }

    function deleteNFT(uint256 _id) public onlyOwner(_id) {
        delete minted[_id];
        emit nftDeleted(msg.sender, _id);
    }

    // returns nft owned by msg.sender
    function own() public view returns (uint256[] memory) {
        return addressToNFTID[msg.sender];
    }

    //owner of nft can make their nft for sale so that others can bid on it
    function makeNFTForSale(uint256 _id) public onlyOwner(_id) {
        minted[_id].isForSale = true;
        forSale.push(_id);
    }

    //it is use to bid on nft with id _id which are for sale
    function bid(uint256 _id) public payable {
        require(minted[_id].owner != address(0), "nft not found");
        require(minted[_id].isForSale, "nft is not for sale");
        // check if msg.sender already bidded or not
        if (bids[_id].biddingAmount[msg.sender] == 0) {
            require(
                minted[_id].price <= msg.value,
                "value should be >= price of nft"
            );
            bids[_id].biddersCount++;
            bids[_id].bidders.push(msg.sender);
            biddedOn[msg.sender].push(_id);
        }
        //setting higgeast bidding and bidder
        if (
            bids[_id].biddingAmount[msg.sender] + msg.value >
            bids[_id].higgestAmount
        ) {
            bids[_id].higgestAmount =
                bids[_id].biddingAmount[msg.sender] +
                msg.value;
            bids[_id].higgestBidder = msg.sender;
        }
        bids[_id].biddingAmount[msg.sender] += msg.value;
    }

    //withdraw from bid
    function withDraw(uint256 _id) public {
        require(_id < index, "nft not found");
        require(minted[_id].isForSale, "nft is not for sale");
        require(
            bids[_id].biddingAmount[msg.sender] > 0,
            "you didn't bid for this nft bidding"
        );
        removeElementFromUintArray(biddedOn[msg.sender], _id);
        uint256 amount = bids[_id].biddingAmount[msg.sender];
        delete bids[_id].biddingAmount[msg.sender];
        bids[_id].biddersCount--;
        payable(msg.sender).transfer(amount);
        removeElementFromAddresstArray(bids[_id].bidders, msg.sender);
        emit withDrawFromBidding(msg.sender, _id, amount);
    }

    /*
        returns id of nft to which msg.sender bidded on
   */
    function myBids() public view returns (uint256[] memory) {
        return biddedOn[msg.sender];
    }

    /*
        Only the owner will proclaim the winner of the bidding, 
        and ownership of the nft will be transferred to the highest bidder, 
        with ether reverting to the loser's address. 
        The highest bidder's ether will be transferred to the former nft owner.
   */
    function declareWinner(uint256 _id)
        public
        onlyOwner(_id)
        returns (address)
    {
        require(minted[_id].isForSale, "nft is not for sale");
        require(
            bids[_id].biddersCount >= 1,
            "no one bidded yet, wait for some time"
        );
        for (uint256 i = 0; i < bids[_id].biddersCount; i++) {
            if (bids[_id].higgestBidder != bids[_id].bidders[i]) {
                // removing _id from bidded array
                removeElementFromUintArray(biddedOn[bids[_id].bidders[i]], _id);
                // transfer their money who lost
                payable(address(bids[_id].bidders[i])).transfer(
                    bids[_id].biddingAmount[bids[_id].bidders[i]]
                );
            }
        }
        address winner = bids[_id].higgestBidder;
        uint256 higgestAmount = bids[_id].higgestAmount;
        payable(minted[_id].owner).transfer(bids[_id].higgestAmount);
        removeElementFromUintArray(forSale, _id);
        minted[_id].isForSale = false;
        minted[_id].owner = winner;
        removeElementFromUintArray(addressToNFTID[msg.sender], _id);
        addressToNFTID[winner].push(_id);
        // now msg.sender don't own nft with id _id
        delete bids[_id];
        // emit ownershipTransfer(msg.sender, winner, _id);
        emit biddingResult(higgestAmount, _id, msg.sender, winner);
        return winner;
    }

    /*
        Only the owner has the ability to terminate bidding, 
        and all deposited tokens will be returned to the bidders' respective accounts.
    */
    function cancelBidding(uint256 _id) public onlyOwner(_id) {
        require(minted[_id].isForSale, "nft is not for sale");
        for (uint256 i = 0; i < bids[_id].biddersCount; i++) {
            removeElementFromUintArray(biddedOn[bids[_id].bidders[i]], _id);
            payable(address(bids[_id].bidders[i])).transfer(
                bids[_id].biddingAmount[bids[_id].bidders[i]]
            );
        }
        removeElementFromUintArray(forSale, _id);
        minted[_id].isForSale = false;
        delete bids[_id];
    }

    /*
        transfer ownership
    */
    function transferOwnerShip(uint256 _id, address transferTo)
        public
        onlyOwner(_id)
    {
        require(!minted[_id].isForSale, "nft is for sale");
        minted[_id].owner = transferTo;
        removeElementFromUintArray(addressToNFTID[msg.sender], _id);
        addressToNFTID[transferTo].push(_id);
        emit ownershipTransfer(msg.sender, transferTo, _id);
    }
}
