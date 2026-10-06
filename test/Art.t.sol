// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IMDPunks} from "../src/IMDPunks.sol";
import {IMDPunksArt} from "../src/IMDPunksArt.sol";
import {PunkTraits} from "../src/PunkTraits.sol";
import {PunkSprites} from "../src/PunkSprites.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {RenderChecks} from "./helpers/RenderChecks.sol";

contract ArtTest is Test {
    using Strings for uint256;
    address constant RESERVE = 0x2E28b29560a6d4812E58680484c685D0352f8ff9;
    IMDPunks punks;
    IMDPunksArt art;

    function setUp() public {
        punks = new IMDPunks(RESERVE);
        art = punks.art();
    }

    function testExactTypeCountsForAll10000() public view {
        uint256[5] memory counts;
        bool[10000] memory ranks;
        for (uint256 n; n < 10_000; ++n) {
            uint256 rank = (n * 7919 + 4321) % 10_000;
            assertFalse(ranks[rank]);
            ranks[rank] = true;
            uint256 expected = rank <= 8 ? 0 : rank <= 32 ? 1 : rank <= 120 ? 2 : rank <= 3960 ? 3 : 4;
            uint256 actual = uint256(punks.typeOf(n));
            assertEq(actual, expected);
            ++counts[actual];
        }
        assertEq(counts[0], 9);
        assertEq(counts[1], 24);
        assertEq(counts[2], 88);
        assertEq(counts[3], 3840);
        assertEq(counts[4], 6039);
    }

    function testAll10000HaveUniqueSlotsAndCompatibleAccessories() public {
        uint256[8] memory distribution;
        bool[87] memory seen;
        for (uint256 n; n < 10_000; ++n) {
            uint8[] memory ids = punks.accessoriesOf(n);
            assertLe(ids.length, 7);
            ++distribution[ids.length];
            uint256 used;
            bool female = punks.typeOf(n) == PunkTraits.Kind.Female;
            for (uint256 i; i < ids.length; ++i) {
                uint256 id = ids[i];
                assertLt(id, 87);
                assertEq(id >= 44, female);
                // Independent ranges from the published catalogue.
                uint256 local = female ? id - 44 : id;
                uint256 slot = local < 12
                    ? 0
                    : local < 20
                        ? 1
                        : local < 25
                            ? 2
                            : local < (female ? 30 : 31)
                                ? 3
                                : local < (female ? 34 : 35) ? 4 : local < (female ? 39 : 40) ? 5 : 6;
                assertEq(used & (1 << slot), 0, "duplicate slot");
                used |= 1 << slot;
                seen[id] = true;
            }
        }
        for (uint256 i; i < 87; ++i) {
            assertTrue(seen[i], "unreachable accessory");
        }
        for (uint256 i; i < 8; ++i) {
            emit log_named_uint(string.concat("Count with ", i.toString(), " accessories"), distribution[i]);
        }
        assertGe(distribution[0], 1);
        assertLe(distribution[0], 25);
        assertGe(distribution[1], 220);
        assertLe(distribution[1], 380);
        assertGe(distribution[2], 3300);
        assertLe(distribution[2], 3900);
        assertGe(distribution[3], 4200);
        assertLe(distribution[3], 4800);
        assertGe(distribution[4], 1200);
        assertLe(distribution[4], 1600);
        assertGe(distribution[5], 100);
        assertLe(distribution[5], 240);
        assertGe(distribution[6] + distribution[7], 5);
        assertLe(distribution[6] + distribution[7], 40);
    }

    function testAll87NamedSpritesAreDistinctAndBounded() public view {
        assertEq(art.ACCESSORY_COUNT(), 87);
        bytes memory runs = PunkSprites.RUNS;
        bytes memory offsets = PunkSprites.OFFSETS;
        bytes32[92] memory spriteHashes;
        bytes32[87] memory nameHashes;
        for (uint256 id; id < 92; ++id) {
            uint256 start = PunkSprites.offset(offsets, id);
            uint256 end = PunkSprites.offset(offsets, id + 1);
            assertGt(end, start);
            assertLe(end, runs.length);
            assertEq((end - start) % 4, 0);
            bytes memory sprite = new bytes(end - start);
            for (uint256 j = start; j < end; j += 4) {
                assertLt(uint8(runs[j]), 24);
                assertLt(uint8(runs[j + 1]), 24);
                assertGt(uint8(runs[j + 2]), 0);
                assertLe(uint256(uint8(runs[j])) + uint8(runs[j + 2]), 24);
                assertLt(uint8(runs[j + 3]), 24);
                for (uint256 k; k < 4; ++k) {
                    sprite[j - start + k] = runs[j + k];
                }
            }
            spriteHashes[id] = keccak256(sprite);
            for (uint256 j; j < id; ++j) {
                assertNotEq(spriteHashes[id], spriteHashes[j]);
            }
            if (id >= 5) {
                (string memory name, uint8 slot, bool female) = art.accessoryInfo(id - 5);
                assertGt(bytes(name).length, 0);
                assertLt(slot, 7);
                assertEq(female, id - 5 >= 44);
                nameHashes[id - 5] = keccak256(bytes(name));
                for (uint256 j; j < id - 5; ++j) {
                    assertNotEq(nameHashes[id - 5], nameHashes[j]);
                }
            }
        }
        assertEq(PunkSprites.offset(offsets, 92), runs.length);
    }

    // Independent batches keep total test gas and parser memory bounded.
    function testMetadataSample000To019() public {
        _sample(0, 20);
    }

    function testMetadataSample020To039() public {
        _sample(20, 40);
    }

    function testMetadataSample040To059() public {
        _sample(40, 60);
    }

    function testMetadataSample060To079() public {
        _sample(60, 80);
    }

    function testMetadataSample080To099() public {
        _sample(80, 100);
    }

    function testMetadataSample100To119() public {
        _sample(100, 120);
    }

    function testMetadataSample120To139() public {
        _sample(120, 140);
    }

    function testMetadataSample140To159() public {
        _sample(140, 160);
    }

    function testMetadataSample160To179() public {
        _sample(160, 180);
    }

    function testMetadataSample180To199() public {
        _sample(180, 200);
    }

    function _sample(uint256 start, uint256 stop) private {
        for (uint256 i = start; i < stop; ++i) {
            this.checkMetadata(i * 47);
        }
    }

    function testRequiredNumbersAndEveryType() public {
        uint256[8] memory ids = [uint256(0), 777, 888, 9999, 1, 127, 300, 473];
        bool[5] memory seen;
        for (uint256 i; i < ids.length; ++i) {
            this.checkMetadata(ids[i]);
            seen[uint256(punks.typeOf(ids[i]))] = true;
        }
        for (uint256 i; i < 5; ++i) {
            assertTrue(seen[i]);
        }
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzMintedMetadataAndImageRoundTrip(uint256 seed) public {
        this.checkMetadata(bound(seed, 0, 9999));
    }

    /// @dev A fresh external frame releases parser/renderer scratch memory between samples.
    function checkMetadata(uint256 number) external {
        string memory beforeImage = punks.imageOf(number);
        if (!punks.isMinted(number)) {
            vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, number));
            punks.tokenURI(number);
            vm.prank(address(uint160(100_000 + number)));
            punks.claim(number);
        }
        string memory json = string(
            RenderChecks.decode64(RenderChecks.strip(bytes(punks.tokenURI(number)), "data:application/json;base64,"))
        );
        assertEq(vm.parseJsonString(json, ".name"), string.concat("IMDPunk #", number.toString()));
        assertEq(
            vm.parseJsonString(json, ".description"), "Original 24 by 24 pixel portraits, living entirely on-chain."
        );
        string memory imageURI = vm.parseJsonString(json, ".image");
        bytes memory svg = RenderChecks.decode64(RenderChecks.strip(bytes(imageURI), "data:image/svg+xml;base64,"));
        assertEq(string(svg), beforeImage);
        RenderChecks.svg(svg);
        string[5] memory typeNames = ["Alien", "Ape", "Zombie", "Female", "Male"];
        assertEq(vm.parseJsonString(json, ".attributes[0].trait_type"), "Type");
        assertEq(vm.parseJsonString(json, ".attributes[0].value"), typeNames[uint256(punks.typeOf(number))]);
        uint8[] memory accessories = punks.accessoriesOf(number);
        string[7] memory slotNames = ["Head", "Eyes", "Mouth", "Facial hair", "Ear", "Neck", "Face mark"];
        for (uint256 i; i < accessories.length; ++i) {
            (string memory name, uint8 slot,) = art.accessoryInfo(accessories[i]);
            string memory key = string.concat(".attributes[", (i + 1).toString(), "]");
            assertEq(vm.parseJsonString(json, string.concat(key, ".trait_type")), slotNames[slot]);
            assertEq(vm.parseJsonString(json, string.concat(key, ".value")), name);
        }
        string memory countKey = string.concat(".attributes[", (accessories.length + 1).toString(), "]");
        assertEq(vm.parseJsonString(json, string.concat(countKey, ".trait_type")), "Accessory count");
        assertEq(vm.parseJsonUint(json, string.concat(countKey, ".value")), accessories.length);
        assertFalse(vm.keyExistsJson(json, string.concat(".attributes[", (accessories.length + 2).toString(), "]")));
    }

    function testMetadataForEveryAccessoryCountIncludingZeroAndSeven() public {
        uint256 found;
        for (uint256 n; n < 10_000 && found != 255; ++n) {
            uint256 count = punks.accessoriesOf(n).length;
            if (found & (1 << count) == 0) {
                found |= 1 << count;
                this.checkMetadata(n);
            }
        }
        assertEq(found, 255);
    }

    function testMetadataStableAcrossClaimTransferAndBlockChanges() public {
        string memory beforeImage = punks.imageOf(300);
        vm.prank(RESERVE);
        punks.claim(300);
        string memory beforeURI = punks.tokenURI(300);
        vm.prank(RESERVE);
        punks.transferFrom(RESERVE, address(0xBEEF), 300);
        vm.warp(block.timestamp + 1000);
        vm.roll(block.number + 100);
        assertEq(punks.imageOf(300), beforeImage);
        assertEq(punks.tokenURI(300), beforeURI);
    }

    function testInvalidInputsRevertBeforeRendering() public {
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.imageOf(10_000);
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        punks.imageOf(type(uint256).max);
        vm.expectRevert(PunkTraits.InvalidNumber.selector);
        art.metadata(10_000);
        vm.expectRevert(PunkTraits.InvalidAccessory.selector);
        art.accessoryInfo(87);
        vm.expectRevert(PunkTraits.InvalidAccessory.selector);
        art.accessoryInfo(type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 10_000));
        punks.tokenURI(10_000);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, type(uint256).max));
        punks.tokenURI(type(uint256).max);
    }

    function testFuzzUnmintedURIReverts(uint256 number) public {
        number = bound(number, 198, type(uint256).max);
        vm.assume(number != 777 && number != 888);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, number));
        punks.tokenURI(number);
    }
}
