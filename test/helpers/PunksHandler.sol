// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "src/IMDPunks.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract InvariantRejectReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(0);
    }
}

/// @dev A spec model of ERC-721 ownership and five lifetime claims. Expected results
/// are decided from ghost state, never from the collection's owners or counters.
/// All destinations are in a closed actor set, so the sum of balances is exact.
contract PunksHandler is Test {
    IMDPunks public immutable punks;
    InvariantRejectReceiver public immutable rejectReceiver;
    address[8] public actors;
    uint256[] public minted;
    mapping(uint256 => address) public expectedOwner;
    mapping(uint256 => address) public expectedApproval;
    mapping(address => mapping(address => bool)) public expectedOperator;
    mapping(address => uint256) public expectedClaims;
    mapping(address => uint256) public expectedBalance;
    uint256 public successfulClaims;
    uint256 public rejectedClaims;
    uint256 public successfulTransfers;
    uint256 public rejectedTransfers;

    constructor(IMDPunks collection, address reserve) {
        punks = collection;
        rejectReceiver = new InvariantRejectReceiver();
        actors[0] = reserve;
        for (uint256 i = 1; i < actors.length; ++i) {
            actors[i] = address(uint160(0xA000 + i));
        }
        for (uint256 i; i < 200; ++i) {
            uint256 id = i < 198 ? i : i == 198 ? 777 : 888;
            minted.push(id);
            expectedOwner[id] = reserve;
        }
        expectedBalance[reserve] = 200;
    }

    /// @dev Fresh ids reach the claim limit; the other modes exercise existing,
    /// reserved and arbitrary out-of-range ids without discarding any fuzz inputs.
    function claim(uint256 actorSeed, uint256 numberSeed, uint8 mode) external {
        uint256 id;
        if (mode % 4 == 0) id = _fresh(numberSeed);
        else if (mode % 4 == 1) id = minted[bound(numberSeed, 0, minted.length - 1)];
        else if (mode % 4 == 2) id = bound(numberSeed, 0, 9999);
        else id = bound(numberSeed, 10_000, type(uint256).max);
        _claim(_actor(actorSeed), id);
    }

    /// @dev Deliberately reach five and six on every invocation, including after
    /// transfers have emptied an actor's balance. This is never a skipped action.
    function exhaustAllowance(uint256 actorSeed, uint256 numberSeed) external {
        address actor = _actor(actorSeed);
        uint256 attempts = 6 - expectedClaims[actor];
        for (uint256 i; i < attempts; ++i) {
            _claim(actor, _fresh(numberSeed));
        }
    }

    function approve(uint256 tokenSeed, uint256 callerSeed, uint256 toSeed, uint8 role) external {
        uint256 id = minted[bound(tokenSeed, 0, minted.length - 1)];
        address owner = expectedOwner[id];
        address caller = _caller(id, callerSeed, role);
        address to = toSeed % 9 == 8 ? address(0) : _actor(toSeed);
        bool allowed = caller == owner || expectedOperator[owner][caller];
        vm.prank(caller);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.approve, (to, id)));
        assertEq(ok, allowed, "approval authorization");
        if (allowed) expectedApproval[id] = to;
        _checkToken(id);
    }

    function setOperator(uint256 ownerSeed, uint256 operatorSeed, bool approved) external {
        address owner = _actor(ownerSeed);
        address operator = operatorSeed % 9 == 8 ? address(0) : _actor(operatorSeed);
        vm.prank(owner);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.setApprovalForAll, (operator, approved)));
        assertEq(ok, operator != address(0), "operator authorization");
        if (ok) expectedOperator[owner][operator] = approved;
        assertEq(punks.isApprovedForAll(owner, operator), expectedOperator[owner][operator]);
    }

    /// @param role Select owner, token-approved, operator-approved or arbitrary caller.
    /// @param mode Select plain transfer, either safe overload, wrong from, or zero to.
    function transfer(uint256 tokenSeed, uint256 callerSeed, uint256 toSeed, uint8 role, uint8 mode) external {
        uint256 id = minted[bound(tokenSeed, 0, minted.length - 1)];
        address owner = expectedOwner[id];
        address caller = _caller(id, callerSeed, role);
        address to = _actor(toSeed);
        address from = owner;
        if (mode % 5 == 3) from = owner == actors[0] ? actors[1] : actors[0];
        if (mode % 5 == 4) to = address(0);
        bool allowed = to != address(0) && from == owner
            && (caller == owner || caller == expectedApproval[id] || expectedOperator[owner][caller]);

        bytes memory data;
        if (mode % 5 == 1) {
            data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", from, to, id);
        } else if (mode % 5 == 2) {
            data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)", from, to, id, hex"1234");
        } else {
            data = abi.encodeCall(punks.transferFrom, (from, to, id));
        }
        vm.prank(caller);
        (bool ok,) = address(punks).call(data);
        assertEq(ok, allowed, "transfer authorization");
        if (allowed) {
            --expectedBalance[owner];
            ++expectedBalance[to];
            expectedOwner[id] = to;
            expectedApproval[id] = address(0);
            ++successfulTransfers;
        } else {
            ++rejectedTransfers;
        }
        _checkToken(id);
    }

    /// @dev Force an authorized transfer to reach the receiver rejection, so an
    /// earlier authorization failure cannot mask missing rollback of the approval.
    function rejectSafeTransfer(uint256 tokenSeed, bool noReceiver) external {
        uint256 id = minted[bound(tokenSeed, 0, minted.length - 1)];
        address owner = expectedOwner[id];
        address to = noReceiver ? address(this) : address(rejectReceiver);
        vm.prank(owner);
        (bool ok,) = address(punks)
            .call(abi.encodeWithSignature("safeTransferFrom(address,address,uint256,bytes)", owner, to, id, hex"abcd"));
        assertFalse(ok, "unsafe recipient accepted");
        ++rejectedTransfers;
        assertEq(punks.balanceOf(to), 0, "rejected receiver kept balance");
        _checkToken(id);
    }

    function transferUnminted(uint256 numberSeed, uint256 actorSeed) external {
        uint256 id = _fresh(numberSeed);
        address caller = _actor(actorSeed);
        vm.prank(caller);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.transferFrom, (caller, actors[0], id)));
        assertFalse(ok, "transfer minted a token");
        ++rejectedTransfers;
        _checkToken(id);
    }

    /// @dev Run after every random action. NFT ownership is checked individually,
    /// not just by comparing counters that could share the same implementation bug.
    function assertModel() external view {
        uint256 supply = punks.totalSupply();
        assertEq(supply, minted.length, "supply != number of distinct issued ids");
        assertEq(supply, 200 + successfulClaims, "supply != reserve + claims");
        assertLe(supply, 10_000, "supply cap");
        uint256 sum;
        uint256 claims;
        for (uint256 i; i < actors.length; ++i) {
            address actor = actors[i];
            assertEq(punks.balanceOf(actor), expectedBalance[actor], "balance mismatch");
            assertEq(punks.claimedBy(actor), expectedClaims[actor], "lifetime counter mismatch");
            assertLe(punks.claimedBy(actor), 5, "lifetime cap");
            sum += punks.balanceOf(actor);
            claims += punks.claimedBy(actor);
            for (uint256 j; j < actors.length; ++j) {
                assertEq(punks.isApprovedForAll(actor, actors[j]), expectedOperator[actor][actors[j]], "operator drift");
            }
        }
        assertEq(sum, supply, "balances do not conserve supply");
        assertEq(claims, successfulClaims, "transfers changed claims");
        for (uint256 i; i < minted.length; ++i) {
            uint256 id = minted[i];
            assertLt(id, 10_000);
            _checkToken(id);
        }
        assertEq(punks.balanceOf(address(rejectReceiver)), 0);
        assertEq(punks.balanceOf(address(this)), 0);
        assertEq(address(punks).balance, 0);
    }

    function _claim(address actor, uint256 id) private {
        bool allowed = id < 10_000 && expectedOwner[id] == address(0) && expectedClaims[actor] < 5;
        vm.prank(actor);
        (bool ok,) = address(punks).call(abi.encodeCall(punks.claim, (id)));
        assertEq(ok, allowed, "claim eligibility");
        if (allowed) {
            expectedOwner[id] = actor;
            ++expectedBalance[actor];
            ++expectedClaims[actor];
            minted.push(id);
            ++successfulClaims;
        } else {
            ++rejectedClaims;
        }
        _checkToken(id);
    }

    function _checkToken(uint256 id) private view {
        address owner = expectedOwner[id];
        assertEq(punks.isMinted(id), owner != address(0), "mint flag mismatch");
        if (owner != address(0)) {
            assertEq(punks.ownerOf(id), owner, "owner mismatch");
            assertEq(punks.getApproved(id), expectedApproval[id], "token approval mismatch");
        } else {
            (bool ok,) = address(punks).staticcall(abi.encodeCall(punks.ownerOf, (id)));
            assertFalse(ok, "unminted owner query succeeded");
            (ok,) = address(punks).staticcall(abi.encodeCall(punks.getApproved, (id)));
            assertFalse(ok, "unminted approval query succeeded");
            (ok,) = address(punks).staticcall(abi.encodeCall(punks.tokenURI, (id)));
            assertFalse(ok, "unminted metadata query succeeded");
        }
    }

    function _actor(uint256 seed) private view returns (address) {
        return actors[bound(seed, 0, actors.length - 1)];
    }

    function _fresh(uint256 seed) private view returns (uint256 id) {
        id = bound(seed, 198, 9999);
        // Only eight actors can claim, so the search always has an unissued result.
        while (expectedOwner[id] != address(0)) {
            id = id == 9999 ? 198 : id + 1;
        }
    }

    function _caller(uint256 id, uint256 seed, uint8 role) private view returns (address) {
        address owner = expectedOwner[id];
        if (role % 4 == 0) return owner;
        if (role % 4 == 1 && expectedApproval[id] != address(0)) return expectedApproval[id];
        if (role % 4 == 2) {
            for (uint256 i; i < actors.length; ++i) {
                if (expectedOperator[owner][actors[i]]) return actors[i];
            }
        }
        return _actor(seed);
    }
}
