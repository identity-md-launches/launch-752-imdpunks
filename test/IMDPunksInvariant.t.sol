// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMDPunks} from "src/IMDPunks.sol";
import {PunksHandler} from "./helpers/PunksHandler.sol";

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 64
/// forge-config: default.invariant.fail-on-revert = true
contract IMDPunksInvariantTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    PunksHandler handler;

    function setUp() public {
        IMDPunks punks = new IMDPunks(RESERVE);
        handler = new PunksHandler(punks, RESERVE);
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = handler.claim.selector;
        selectors[1] = handler.exhaustAllowance.selector;
        selectors[2] = handler.approve.selector;
        selectors[3] = handler.setOperator.selector;
        selectors[4] = handler.transfer.selector;
        selectors[5] = handler.rejectSafeTransfer.selector;
        selectors[6] = handler.transferUnminted.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_ownershipSupplyApprovalsAndLifetimeClaimsMatchHistory() public view {
        handler.assertModel();
    }

    /// @dev Pin a productive sequence too: a suite of caught reverts cannot pass
    /// this test. The invariant runner separately explores arbitrary interleavings.
    function testHandlerReachesClaimsTransfersRevocationsAndFailures() public {
        handler.exhaustAllowance(1, 9999);
        handler.assertModel();
        assertEq(handler.successfulClaims(), 5);
        assertEq(handler.rejectedClaims(), 1);
        // Delegate reserve id 0 to actor 2, then exercise the token approval.
        handler.approve(0, 0, 2, 0);
        handler.transfer(0, 2, 1, 1, 0);
        handler.assertModel();
        // Actor 1 delegates to actor 3, who self-transfers then sends to actor 2.
        handler.setOperator(1, 3, true);
        handler.transfer(0, 3, 1, 2, 1);
        handler.transfer(0, 3, 2, 2, 2);
        handler.setOperator(1, 3, false);
        handler.transfer(0, 3, 1, 3, 0);
        handler.rejectSafeTransfer(0, false);
        handler.rejectSafeTransfer(198, true);
        handler.transferUnminted(500, 3);
        // The empty-balance claimant remains out of lifetime claims.
        for (uint256 i = 200; i < 205; ++i) {
            handler.transfer(i, 1, 0, 0, 0);
        }
        handler.exhaustAllowance(1, 500);
        handler.assertModel();
        assertEq(handler.successfulClaims(), 5);
        assertEq(handler.successfulTransfers(), 8);
        assertEq(handler.rejectedTransfers(), 4);
        assertEq(handler.rejectedClaims(), 2);
    }

    function testApprovalCannotBeRedelegatedOrSurviveTransfer() public {
        handler.approve(0, 0, 2, 0);
        // A token-approved account cannot grant another token approval.
        handler.approve(0, 2, 3, 1);
        handler.setOperator(0, 3, true);
        handler.approve(0, 3, 2, 2);
        handler.setOperator(0, 3, false);
        handler.transfer(0, 3, 1, 3, 0);
        handler.assertModel();
        assertEq(handler.rejectedTransfers(), 1, "revoked operator remained authorized");

        handler.transfer(0, 2, 1, 1, 0);
        handler.transfer(0, 2, 0, 3, 0);
        handler.assertModel();
        assertEq(handler.rejectedTransfers(), 2, "approval followed token to new owner");

        // A self-transfer must also clear the token approval.
        handler.approve(0, 1, 2, 0);
        handler.transfer(0, 2, 1, 1, 0);
        handler.transfer(0, 2, 3, 3, 0);
        handler.assertModel();
        assertEq(handler.successfulTransfers(), 2);
        assertEq(handler.rejectedTransfers(), 3);
        assertEq(handler.successfulClaims(), 0);
    }
}
