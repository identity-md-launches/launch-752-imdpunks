// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IMDPunksArt} from "./IMDPunksArt.sol";
import {PunkTraits} from "./PunkTraits.sol";

/// @notice A fixed universe of 10,000 fully on-chain pixel portraits, with five lifetime claims per address.
contract IMDPunks is ERC721 {
    string public constant NAME = "IMDPunks";
    string public constant SYMBOL = "IMDPUNK";
    uint256 public constant MAX_SUPPLY = 10_000;
    address public immutable reserve;
    IMDPunksArt public immutable art;
    uint256 public totalSupply = 200;
    mapping(address => uint256) public claimedBy;

    error ClaimLimit();
    error AlreadyMinted();
    error ZeroReserve();

    /// @param reserveAddress Beneficiary of ids 0..197, 777 and 888. Never inferred from the factory caller.
    constructor(address reserveAddress) ERC721(NAME, SYMBOL) {
        if (reserveAddress == address(0)) revert ZeroReserve();
        reserve = reserveAddress;
        art = new IMDPunksArt();
        // The ERC721 balance matches the implicit owners returned by _ownerOf from deployment onward.
        _increaseBalance(reserveAddress, 200);
        for (uint256 i; i < 198; ++i) {
            emit Transfer(address(0), reserveAddress, i);
        }
        emit Transfer(address(0), reserveAddress, 777);
        emit Transfer(address(0), reserveAddress, 888);
    }

    function name() public pure override returns (string memory) {
        return NAME;
    }

    function symbol() public pure override returns (string memory) {
        return SYMBOL;
    }

    /// @dev Deliberately uses _mint: claiming never calls an untrusted receiver.
    function claim(uint256 number) external {
        if (number >= MAX_SUPPLY) revert PunkTraits.InvalidNumber();
        if (isMinted(number)) revert AlreadyMinted();
        if (claimedBy[msg.sender] >= 5) revert ClaimLimit();
        ++claimedBy[msg.sender];
        ++totalSupply;
        _mint(msg.sender, number);
    }

    function isMinted(uint256 number) public view returns (bool) {
        return _ownerOf(number) != address(0);
    }

    function typeOf(uint256 number) external pure returns (PunkTraits.Kind) {
        return PunkTraits.kind(number);
    }

    function accessoriesOf(uint256 number) external pure returns (uint8[] memory) {
        return PunkTraits.accessories(number);
    }

    function imageOf(uint256 number) external view returns (string memory) {
        return art.imageOf(number);
    }

    function tokenURI(uint256 number) public view override returns (string memory) {
        _requireOwned(number);
        return art.metadata(number);
    }

    /// @dev No burn path exists. Once transferred, the explicit nonzero owner permanently supersedes this fallback.
    function _ownerOf(uint256 number) internal view override returns (address) {
        address explicitOwner = super._ownerOf(number);
        if (explicitOwner != address(0)) return explicitOwner;
        if (number < 198 || number == 777 || number == 888) return reserve;
        return address(0);
    }
}
