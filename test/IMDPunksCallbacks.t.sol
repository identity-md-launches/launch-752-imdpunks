// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "src/IMDPunks.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @dev Recursively safe-transfers the same NFT to itself. Each callback attempts
/// another public claim and sends it away immediately, keeping its balance low.
/// Optionally rejects only after all nested calls have mutated collection state.
contract NestedPunkReceiver is IERC721Receiver {
    error RejectAfterNestedCalls();

    IMDPunks public immutable punks;
    address public immutable sink;
    bool public immutable reject;
    uint256 public callbacks;
    uint256 public successes;
    uint256 public failures;
    uint256 public nextId = 6000;

    constructor(IMDPunks collection, address destination, bool rejectAtEnd) {
        punks = collection;
        sink = destination;
        reject = rejectAtEnd;
    }

    function preclaimAndSend(uint256 count) external {
        for (uint256 i; i < count; ++i) {
            punks.claim(5000 + i);
            punks.transferFrom(address(this), sink, 5000 + i);
        }
    }

    function claimOne(uint256 id) external {
        punks.claim(id);
    }

    function onERC721Received(address operator, address from, uint256 id, bytes calldata data)
        external
        returns (bytes4)
    {
        require(msg.sender == address(punks), "wrong collection");
        require(punks.ownerOf(id) == address(this), "callback before ownership update");
        require(punks.getApproved(id) == address(0), "approval live in callback");
        require(keccak256(data) == keccak256(hex"000102ff"), "callback data changed");
        if (callbacks == 0) {
            require(from == punks.reserve() && operator == address(0xC011), "wrong outer context");
        } else {
            require(from == address(this) && operator == address(this), "wrong nested context");
        }
        ++callbacks;

        (bool duplicate,) = address(punks).call(abi.encodeCall(punks.claim, (id)));
        require(!duplicate, "callback reminted received NFT");
        uint256 candidate = nextId++;
        try punks.claim(candidate) {
            ++successes;
            punks.transferFrom(address(this), sink, candidate);
        } catch {
            ++failures;
        }

        if (callbacks < 8) {
            punks.safeTransferFrom(address(this), address(this), id, data);
        } else {
            punks.transferFrom(address(this), sink, id);
            if (reject) revert RejectAfterNestedCalls();
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract IMDPunksCallbacksTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    address constant OPERATOR = address(0xC011);
    address constant SINK = address(0xD357);
    IMDPunks punks;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
    }

    /// forge-config: default.fuzz.runs = 128
    function testFuzzNestedCallbacksCannotResetLifetimeClaims(uint256 priorSeed, uint256 reserveSeed) public {
        uint256 prior = bound(priorSeed, 0, 5);
        uint256 id = _reserveId(reserveSeed);
        NestedPunkReceiver receiver = new NestedPunkReceiver(punks, SINK, false);
        receiver.preclaimAndSend(prior);
        assertEq(punks.balanceOf(address(receiver)), 0);
        vm.prank(RESERVE);
        punks.approve(OPERATOR, id);
        vm.prank(OPERATOR);
        punks.safeTransferFrom(RESERVE, address(receiver), id, hex"000102ff");

        assertEq(receiver.callbacks(), 8, "nested callback path not reached");
        assertEq(receiver.successes(), 5 - prior);
        assertEq(receiver.failures(), 3 + prior);
        assertEq(punks.claimedBy(address(receiver)), 5);
        assertEq(punks.claimedBy(SINK), 0);
        assertEq(punks.claimedBy(RESERVE), 0);
        assertEq(punks.totalSupply(), 205);
        assertEq(punks.balanceOf(RESERVE), 199);
        assertEq(punks.balanceOf(address(receiver)), 0);
        assertEq(punks.balanceOf(SINK), 6);
        assertEq(punks.ownerOf(id), SINK);
        assertEq(punks.getApproved(id), address(0));
        for (uint256 i; i < 8; ++i) {
            assertEq(punks.isMinted(6000 + i), i < 5 - prior);
            if (i < 5 - prior) assertEq(punks.ownerOf(6000 + i), SINK);
        }
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        receiver.claimOne(6008);
        assertFalse(punks.isMinted(6008));
        assertEq(punks.totalSupply(), 205);
    }

    /// forge-config: default.fuzz.runs = 128
    function testFuzzReceiverRejectionRollsBackNestedMintsAndTransfers(uint256 priorSeed, uint256 reserveSeed) public {
        uint256 prior = bound(priorSeed, 0, 5);
        uint256 id = _reserveId(reserveSeed);
        NestedPunkReceiver receiver = new NestedPunkReceiver(punks, SINK, true);
        receiver.preclaimAndSend(prior);
        vm.prank(RESERVE);
        punks.approve(OPERATOR, id);

        // These calls must be reached, even though all their effects are reverted.
        vm.expectCall(address(punks), abi.encodeCall(punks.claim, (6000)));
        vm.expectCall(address(punks), abi.encodeCall(punks.claim, (6007)));
        vm.expectRevert(NestedPunkReceiver.RejectAfterNestedCalls.selector);
        vm.prank(OPERATOR);
        punks.safeTransferFrom(RESERVE, address(receiver), id, hex"000102ff");

        assertEq(receiver.callbacks(), 0);
        assertEq(receiver.successes(), 0);
        assertEq(receiver.failures(), 0);
        assertEq(receiver.nextId(), 6000);
        assertEq(punks.ownerOf(id), RESERVE);
        assertEq(punks.getApproved(id), OPERATOR);
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(address(receiver)), 0);
        assertEq(punks.balanceOf(SINK), prior);
        assertEq(punks.claimedBy(address(receiver)), prior);
        assertEq(punks.claimedBy(SINK), 0);
        assertEq(punks.totalSupply(), 200 + prior);
        for (uint256 i; i < 8; ++i) {
            assertFalse(punks.isMinted(6000 + i));
            vm.expectRevert();
            punks.tokenURI(6000 + i);
        }
        // The restored approval is usable; no stale explicit owner traps the reserve.
        vm.prank(OPERATOR);
        punks.transferFrom(RESERVE, SINK, id);
        assertEq(punks.ownerOf(id), SINK);
        assertEq(punks.getApproved(id), address(0));
        assertEq(punks.balanceOf(RESERVE), 199);
        assertEq(punks.balanceOf(SINK), prior + 1);
        assertEq(punks.totalSupply(), 200 + prior);
    }

    function testNestedCallbackAtZeroAllowance() public {
        testFuzzNestedCallbacksCannotResetLifetimeClaims(0, 0);
    }

    function testNestedCallbackAtExhaustedAllowance() public {
        testFuzzNestedCallbacksCannotResetLifetimeClaims(5, 199);
    }

    function testRejectionAfterNestedClaimsOnSpecialReserve() public {
        testFuzzReceiverRejectionRollsBackNestedMintsAndTransfers(0, 198);
    }

    function _reserveId(uint256 seed) private pure returns (uint256) {
        uint256 index = bound(seed, 0, 199);
        return index < 198 ? index : index == 198 ? 777 : 888;
    }
}
