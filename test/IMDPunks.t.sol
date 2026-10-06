// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {PunkTraits} from "../src/PunkTraits.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ClaimReceiver is IERC721Receiver {
    IMDPunks immutable punks;
    address immutable reserve;
    uint256 public callbacks;
    uint256 public successes;
    uint256 public failures;
    bool public duplicate;
    bool public theft;
    address constant SINK = address(0xBEEF);

    constructor(IMDPunks collection, address beneficiary) {
        punks = collection;
        reserve = beneficiary;
    }

    function start() external {
        punks.claim(600);
    }

    function onERC721Received(address, address, uint256 number, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(punks));
        ++callbacks;
        (duplicate,) = address(punks).call(abi.encodeCall(punks.claim, (number)));
        (theft,) = address(punks).call(abi.encodeCall(punks.transferFrom, (reserve, address(this), 888)));
        for (uint256 i = 601; i < 607; ++i) {
            try punks.claim(i) {
                ++successes;
            } catch {
                ++failures;
            }
        }
        // A receiver may transfer the received token again before its callback returns.
        punks.transferFrom(address(this), SINK, number);
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract RejectReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return bytes4(0);
    }
}

contract IMDPunksTest is Test {
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);
    address constant OPERATOR = address(0xCAFE);
    IMDPunks punks;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
    }

    function _reserved(uint256 i) internal pure returns (bool) {
        return i < 198 || i == 777 || i == 888;
    }

    function testDeploymentGasEventsAndFactoryBeneficiary() public {
        bytes memory code = abi.encodePacked(type(IMDPunks).creationCode, abi.encode(RESERVE));
        vm.recordLogs();
        uint256 beforeGas = gasleft();
        address deployedAddress;
        // Native CREATE2, like the launch factory. Avoid test-runner deployment substitutions.
        assembly ("memory-safe") { deployedAddress := create2(0, add(code, 32), mload(code), 0) }
        IMDPunks deployed = IMDPunks(deployedAddress);
        uint256 deploymentGas = beforeGas - gasleft();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Include conservative transaction calldata, CREATE2 hashing and base transaction overhead.
        uint256 initSize = type(IMDPunks).creationCode.length + 32;
        uint256 gasUpperBound = deploymentGas + 21_000 + initSize * 16 + 8 * ((initSize + 31) / 32);
        emit log_named_uint("CREATE execution gas", deploymentGas);
        emit log_named_uint("Deployment gas including conservative factory/transaction allowance", gasUpperBound);
        assertGt(deploymentGas, 4_000_000, "deployment must be metered");
        assertLt(gasUpperBound, 10_000_000);
        assertLt(address(deployed).code.length, 24_577);
        assertLt(address(deployed.art()).code.length, 24_577);
        assertLt(initSize, 49_153);
        assertEq(entries.length, 200);
        for (uint256 i; i < 200; ++i) {
            uint256 number = i < 198 ? i : i == 198 ? 777 : 888;
            assertEq(entries[i].emitter, address(deployed));
            assertEq(entries[i].topics.length, 4);
            assertEq(entries[i].topics[0], keccak256("Transfer(address,address,uint256)"));
            assertEq(entries[i].topics[1], bytes32(0));
            assertEq(entries[i].topics[2], bytes32(uint256(uint160(RESERVE))));
            assertEq(uint256(entries[i].topics[3]), number);
            assertEq(deployed.ownerOf(number), RESERVE);
        }
        assertEq(deployed.balanceOf(RESERVE), 200);
        assertEq(deployed.balanceOf(address(this)), 0);
        assertEq(deployed.totalSupply(), 200);
        assertEq(deployed.claimedBy(RESERVE), 0);
        assertEq(deployed.reserve(), RESERVE);
    }

    function testConstructorRejectsZeroReserve() public {
        vm.expectRevert(IMDPunks.ZeroReserve.selector);
        new IMDPunks(address(0));
    }

    function testNameSymbolAndInterfaces() public view {
        assertEq(punks.name(), "IMDPunks");
        assertEq(punks.symbol(), "IMDPUNK");
        assertEq(punks.MAX_SUPPLY(), 10_000);
        assertTrue(punks.supportsInterface(0x01ffc9a7));
        assertTrue(punks.supportsInterface(0x80ac58cd));
        assertTrue(punks.supportsInterface(0x5b5e139f));
        assertFalse(punks.supportsInterface(0xffffffff));
        assertFalse(punks.supportsInterface(0x2a55205a)); // No royalties.
        assertFalse(punks.supportsInterface(0x780e9d63)); // No claim of full enumeration support.
    }

    function testEveryReserveCanTransferOutAndBackWithoutResurrection() public {
        for (uint256 i; i < 200; ++i) {
            uint256 number = i < 198 ? i : i == 198 ? 777 : 888;
            assertEq(punks.ownerOf(number), RESERVE);
            vm.prank(RESERVE);
            punks.transferFrom(RESERVE, ALICE, number);
            assertEq(punks.ownerOf(number), ALICE);
            assertEq(punks.balanceOf(RESERVE), 199 - i);
            assertEq(punks.balanceOf(ALICE), i + 1);
            assertTrue(punks.isMinted(number));
            vm.prank(RESERVE);
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, RESERVE, number));
            punks.transferFrom(ALICE, RESERVE, number);
        }
        assertEq(punks.balanceOf(RESERVE), 0);
        for (uint256 i; i < 200; ++i) {
            uint256 number = i < 198 ? i : i == 198 ? 777 : 888;
            vm.prank(ALICE);
            punks.transferFrom(ALICE, RESERVE, number);
        }
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(ALICE), 0);
        assertEq(punks.totalSupply(), 200);
        assertEq(punks.claimedBy(ALICE), 0);
    }

    function testClaimFailuresAndLifetimeLimitSurvivesTransfers() public {
        vm.startPrank(ALICE);
        for (uint256 i; i < 200; ++i) {
            uint256 number = i < 198 ? i : i == 198 ? 777 : 888;
            vm.expectRevert(IMDPunks.AlreadyMinted.selector);
            punks.claim(number);
        }
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.claim(10_000);
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.claim(type(uint256).max);
        for (uint256 i = 198; i < 203; ++i) {
            punks.claim(i);
            assertEq(punks.ownerOf(i), ALICE);
            punks.transferFrom(ALICE, BOB, i);
        }
        vm.expectRevert(IMDPunks.AlreadyMinted.selector);
        punks.claim(198);
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        punks.claim(203);
        vm.stopPrank();
        assertEq(punks.balanceOf(ALICE), 0);
        assertEq(punks.claimedBy(ALICE), 5);
        assertEq(punks.balanceOf(BOB), 5);
        assertEq(punks.claimedBy(BOB), 0);
        vm.startPrank(BOB);
        for (uint256 i = 203; i < 208; ++i) {
            punks.claim(i);
        }
        vm.expectRevert(IMDPunks.ClaimLimit.selector);
        punks.claim(208);
        vm.stopPrank();
        assertEq(punks.balanceOf(BOB), 10);
        assertEq(punks.totalSupply(), 210);
        // Reserved allocations do not use the reserve's five public claims.
        vm.prank(RESERVE);
        punks.claim(208);
        assertEq(punks.claimedBy(RESERVE), 1);
    }

    function testAll10000ExistAndSupplyCannotIncreaseFurther() public {
        uint256 claimed;
        for (uint256 i; i < 10_000; ++i) {
            if (_reserved(i)) continue;
            address claimant = address(uint160(0x100000 + claimed / 5));
            vm.prank(claimant);
            punks.claim(i);
            assertEq(punks.ownerOf(i), claimant);
            assertTrue(punks.isMinted(i));
            ++claimed;
        }
        assertEq(claimed, 9800);
        assertEq(punks.totalSupply(), 10_000);
        for (uint256 i; i < 1960; ++i) {
            assertEq(punks.claimedBy(address(uint160(0x100000 + i))), 5);
            assertEq(punks.balanceOf(address(uint160(0x100000 + i))), 5);
        }
        vm.startPrank(BOB);
        uint256[5] memory taken = [uint256(0), 777, 888, 200, 9999];
        for (uint256 i; i < taken.length; ++i) {
            vm.expectRevert(IMDPunks.AlreadyMinted.selector);
            punks.claim(taken[i]);
        }
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.claim(10_000);
        vm.stopPrank();
        assertEq(punks.totalSupply(), 10_000);
    }

    function testApprovalAuthorizationAndSelfTransfer() public {
        vm.prank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, ALICE, 0));
        punks.transferFrom(RESERVE, ALICE, 0);
        vm.prank(RESERVE);
        punks.approve(OPERATOR, 0);
        assertEq(punks.getApproved(0), OPERATOR);
        vm.prank(OPERATOR);
        punks.transferFrom(RESERVE, ALICE, 0);
        assertEq(punks.getApproved(0), address(0));
        vm.prank(ALICE);
        punks.setApprovalForAll(OPERATOR, true);
        vm.prank(OPERATOR);
        punks.transferFrom(ALICE, ALICE, 0);
        assertEq(punks.balanceOf(ALICE), 1);
        vm.prank(OPERATOR);
        punks.transferFrom(ALICE, BOB, 0);
        vm.prank(ALICE);
        punks.setApprovalForAll(OPERATOR, false);
        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, OPERATOR, 0));
        punks.transferFrom(BOB, ALICE, 0);
        vm.prank(RESERVE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721IncorrectOwner.selector, BOB, 777, RESERVE));
        punks.transferFrom(BOB, ALICE, 777);
        vm.prank(RESERVE);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(0)));
        punks.transferFrom(RESERVE, address(0), 777);
    }

    function testSafeTransferRejectRollsBackImplicitOwnerAndApproval() public {
        RejectReceiver receiver = new RejectReceiver();
        vm.prank(RESERVE);
        punks.approve(OPERATOR, 777);
        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(receiver)));
        punks.safeTransferFrom(RESERVE, address(receiver), 777, "check");
        assertEq(punks.ownerOf(777), RESERVE);
        assertEq(punks.balanceOf(RESERVE), 200);
        assertEq(punks.balanceOf(address(receiver)), 0);
        assertEq(punks.getApproved(777), OPERATOR);
        vm.prank(OPERATOR);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidReceiver.selector, address(this)));
        punks.safeTransferFrom(RESERVE, address(this), 777);
    }

    function testCallbackCannotBypassLifetimeLimitOrStealReserve() public {
        ClaimReceiver receiver = new ClaimReceiver(punks, RESERVE);
        receiver.start();
        assertEq(receiver.callbacks(), 0); // _mint never calls the recipient.
        vm.prank(RESERVE);
        punks.safeTransferFrom(RESERVE, address(receiver), 0);
        assertEq(receiver.callbacks(), 1);
        assertEq(receiver.successes(), 4);
        assertEq(receiver.failures(), 2);
        assertFalse(receiver.duplicate());
        assertFalse(receiver.theft());
        assertEq(punks.claimedBy(address(receiver)), 5);
        assertEq(punks.balanceOf(address(receiver)), 5);
        assertEq(punks.balanceOf(RESERVE), 199);
        assertEq(punks.ownerOf(0), address(0xBEEF));
        assertEq(punks.ownerOf(888), RESERVE);
        assertEq(punks.totalSupply(), 205);
    }

    function testNoEthOrExtraMintAdminEntryPoints() public {
        vm.deal(ALICE, 1 ether);
        vm.startPrank(ALICE);
        (bool ok,) = address(punks).call{value: 1}("");
        assertFalse(ok);
        (ok,) = address(punks).call{value: 1}(abi.encodeCall(punks.claim, (200)));
        assertFalse(ok);
        (ok,) = address(punks).call(abi.encodeWithSignature("mint(address,uint256)", ALICE, 200));
        assertFalse(ok);
        (ok,) = address(punks).call(abi.encodeWithSignature("burn(uint256)", 0));
        assertFalse(ok);
        (ok,) = address(punks).call(abi.encodeWithSignature("owner()"));
        assertFalse(ok);
        (ok,) = address(punks).call(abi.encodeWithSignature("pause()"));
        assertFalse(ok);
        (ok,) = address(punks).call(abi.encodeWithSignature("withdraw()"));
        assertFalse(ok);
        vm.stopPrank();
        assertEq(address(punks).balance, 0);
        assertEq(punks.totalSupply(), 200);
    }

    function testQueryFailures() public {
        assertFalse(punks.isMinted(198));
        assertFalse(punks.isMinted(10_000));
        assertFalse(punks.isMinted(type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, address(0)));
        punks.balanceOf(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 198));
        punks.ownerOf(198);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 198));
        punks.getApproved(198);
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.typeOf(10_000);
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.accessoriesOf(type(uint256).max);
    }

    function testFuzzExactNumberAndLifetimeClaimAccounting(uint256 raw, address claimant) public {
        uint256 number = bound(raw, 198, 9999);
        vm.assume(number != 777 && number != 888);
        vm.assume(claimant != address(0) && claimant != RESERVE && claimant != address(vm));
        vm.prank(claimant);
        punks.claim(number);
        assertEq(punks.ownerOf(number), claimant);
        assertEq(punks.balanceOf(claimant), 1);
        assertEq(punks.totalSupply(), 201);
        assertEq(punks.claimedBy(claimant), 1);
        vm.prank(claimant);
        vm.expectRevert(IMDPunks.AlreadyMinted.selector);
        punks.claim(number);
    }

    function testApplicationBytecodeHasNoForbiddenOpcodes() public view {
        _checkCode(address(punks).code);
        _checkCode(address(punks.art()).code);
    }

    function _checkCode(bytes memory code) private pure {
        for (uint256 j; j < code.length; ++j) {
            uint8 op = uint8(code[j]);
            if (op >= 0x60 && op <= 0x7f) {
                j += op - 0x5f;
                continue;
            }
            require(op != 0xf4 && op != 0xf2 && op != 0xff, "forbidden opcode");
        }
    }
}
