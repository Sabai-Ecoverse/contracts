// SPDX-License-Identifier: MIT
//
// SABAI Ecoverse Early NFT is an ERC721 compliant smart contract for this project:
// (https://sabaiecoverse.com)  
//

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SabaiEarlyNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    string public baseURI;
    string public baseExtension = ".json";
    bool public whiteListEnable = true;

    bool public maxMintEnabled = true;
    uint public maxMint = 0;

    address private withdrawAddress;

    uint[] public types = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
    mapping(uint => typeData) public typesDataMap;
    mapping(uint => uint[]) private typesIds;
    mapping(address=>uint) public addressesTokensCounts;

    mapping(address => bool) private whiteList;

    struct typeData {
        uint minId;
        uint maxId;
        uint count;
        uint cost;
    }

    uint typesIncrement = 13;
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        address _withdrawAddress
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
        withdrawAddress = _withdrawAddress;
        
        // 1 landowner
        typesDataMap[1] = typeData(351, 450, 0, 3 ether); // 1 tier 100
        typesDataMap[2] = typeData(201, 350, 0, 2 ether); // 2 tier 150 
        typesDataMap[3] = typeData(1, 200, 0, 1 ether); // 3 tier 200
        // 2 resort
        typesDataMap[4] = typeData(801, 900, 0, 3 ether); // 1 tier 100
        typesDataMap[5] = typeData(651, 800, 0, 2 ether); // 2 tier 150
        typesDataMap[6] = typeData(451, 650, 0, 1 ether); // 3 tier 200
        // 3 employer
        typesDataMap[7] = typeData(1251, 1350, 0, 3 ether); // 1 tier 100
        typesDataMap[8] = typeData(1101, 1250, 0, 2 ether); // 2 tier 150
        typesDataMap[9] = typeData(901, 1100, 0, 1 ether); // 3 tier 200
        // 4 incentive
        typesDataMap[10] = typeData(1701, 1800, 0, 3 ether); // 1 tier 100
        typesDataMap[11] = typeData(1551, 1700, 0, 2 ether); // 2 tier 150
        typesDataMap[12] = typeData(1351, 1550, 0, 1 ether); // 3 tier 200
        // 5 tester
        typesDataMap[13] = typeData(1801, 1850, 0, 3 ether); // 1 tier 50
    }

    function withdraw() public payable withdrawOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");
        (bool success, ) = (withdrawAddress).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function _baseExtension() internal view virtual returns (string memory) {
        return baseExtension;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function addToWhiteList(address _address) public onlyOwner {
        require(whiteListEnable, "whitelist disabled");

        whiteList[_address] = true;
    }

    function addToWhiteListMany(address[] memory _addresses) public onlyOwner {
        require(whiteListEnable, "whitelist disabled");

        for(uint index=0; index<_addresses.length; index++) {
            whiteList[_addresses[index]] = true;
        }
    }

    function deleteFromWhiteList(address _address) public onlyOwner {
        require(whiteListEnable, "whitelist disabled");

        whiteList[_address] = false;
    }

    function enableWhiteList() public onlyOwner {
        require(!whiteListEnable, "whitelist already enabled");

        whiteListEnable = true;
    }

    function disableWhiteList() public onlyOwner {
        require(whiteListEnable, "whitelist already disabled");

        whiteListEnable = false;
    }

    function verifyAddress(address _address) public view returns(bool) {
        require(whiteListEnable, "whitelist disabled");

        if (_address == owner()) return true;
        return whiteList[_address];
    }

    modifier whiteListed() {
        if (whiteListEnable) {
            require(whiteList[msg.sender] || msg.sender == owner(), "you are not on the whitelist");
        }
        _;
    }

    modifier withdrawOwner() {
        require(msg.sender == owner() || msg.sender == withdrawAddress, "access denied for your address");
        _;
    }

    function setMaxMint(uint _newMaxMint) public onlyOwner {
        maxMint = _newMaxMint;
    }

    function maxMintEnable() public onlyOwner {
        maxMintEnabled = true;
    }

    function maxMintDisable() public onlyOwner {
        maxMintEnabled = false;
    }

    function mint(uint _typeId) public payable whiteListed {
        require(_containsUint(types, _typeId), "incorrect type");
        require(typesDataMap[_typeId].maxId - typesDataMap[_typeId].minId + 1 > typesDataMap[_typeId].count, "limit reached for this type");
        require(msg.value == typesDataMap[_typeId].cost, "incorrect transaction amount");
        if (maxMintEnabled == true) {
            require(totalSupply() < maxMint, "mint limit");
        }

        if (whiteListEnable == true) {
            require(addressesTokensCounts[msg.sender] < 2, "limit of minting tokens for this address");
        }

        uint incrementId = typesDataMap[_typeId].minId + typesDataMap[_typeId].count;

        typesDataMap[_typeId].count++;

        typesIds[_typeId].push(incrementId);

        _safeMint(msg.sender, incrementId);
        addressesTokensCounts[msg.sender]+=1;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory)
    {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
            ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
            : "";
    }

    function addType(uint _countTokens, uint _price) external onlyOwner {
        require(_price > 0, "incorrect price parameter");

        typesIncrement++;

        typesDataMap[typesIncrement] = typeData(typesDataMap[typesIncrement - 1].maxId + 1, typesDataMap[typesIncrement - 1].maxId + _countTokens, 0, _price);
        types.push(typesIncrement);

        maxMint=typesDataMap[typesIncrement].maxId;
    }

    function getTypes() public view returns(uint[] memory) {
        return types;
    }

    function _containsUint(uint[] memory _arr, uint _elem) internal pure returns(bool) {
        if (_arr.length == 0) {
            return false;
        }

        for (uint i = 0; i < _arr.length; i++) {
            if (_arr[i] == _elem) {
                return true;
            }
        }

        return false;
    }
}