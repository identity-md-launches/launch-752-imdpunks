// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {PunkTraits} from "./PunkTraits.sol";
import {PunkSprites} from "./PunkSprites.sol";

/// @notice Pure, immutable renderer. Created by IMDPunks; it has no storage or privileged functions.
contract IMDPunksArt {
    using Strings for uint256;
    uint256 public constant ACCESSORY_COUNT = 87;
    string public constant DESCRIPTION = "Original 24 by 24 pixel portraits, living entirely on-chain.";
    // Palette: background, ink, skin, shadow, light, eyes, shirt, and original accessory colours.
    bytes private constant PALETTE =
        "#b7cacc#202735#c18b69#905e4d#e6b18c#f4e4c4#435674#49333b#e5b85d#d47b68#398e95#506fb0#b79bc8#e8ece2#bc6488#748568#805745#78838e#c8d98a#98534f#d5e4e9#ad7254#8caab7#685471";
    bytes private constant SKINS =
        "#c18b69#905e4d#e6b18c#805647#593e38#a6775c#e0ad8c#ae7c64#f4cba6#a96d50#754a3e#cd9470#6f4b42#483439#996953#d2a177#a87558#edc39b";

    function accessoryInfo(uint256 id) external pure returns (string memory name, uint8 slot, bool female) {
        (slot, female) = PunkTraits.info(id);
        name = PunkSprites.accessoryName(id);
    }

    function imageOf(uint256 number) public pure returns (string memory) {
        PunkTraits.Kind t = PunkTraits.kind(number);
        uint8[] memory accessories = PunkTraits.accessories(number);
        bytes memory pixels = new bytes(576);
        bytes memory runs = PunkSprites.RUNS;
        bytes memory offsets = PunkSprites.OFFSETS;
        _paint(pixels, runs, offsets, uint256(t));
        for (uint256 i; i < accessories.length; ++i) {
            _paint(pixels, runs, offsets, accessories[i] + 5);
        }
        bytes memory palette = _palette(number, t);
        // At most 576 runs of <= 59 bytes plus the header. Writes stay below 40,000 bytes.
        bytes memory svg = new bytes(40_000);
        uint256 at = _append(
            svg, 0, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" shape-rendering="crispEdges">'
        );
        for (uint256 y; y < 24; ++y) {
            uint256 x;
            while (x < 24) {
                uint256 color = uint8(pixels[y * 24 + x]);
                uint256 end = x + 1;
                while (end < 24 && pixels[y * 24 + end] == bytes1(uint8(color))) ++end;
                at = _rect(svg, at, x, y, end - x, palette, color);
                x = end;
            }
        }
        at = _append(svg, at, "</svg>");
        assembly ("memory-safe") { mstore(svg, at) }
        return string(svg);
    }

    function metadata(uint256 number) external pure returns (string memory) {
        PunkTraits.Kind t = PunkTraits.kind(number);
        uint8[] memory accessories = PunkTraits.accessories(number);
        bytes memory attributes = abi.encodePacked('{"trait_type":"Type","value":"', PunkTraits.typeName(t), '"}');
        for (uint256 i; i < accessories.length; ++i) {
            (uint8 slot,) = PunkTraits.info(accessories[i]);
            attributes = abi.encodePacked(
                attributes,
                ',{"trait_type":"',
                PunkTraits.slotName(slot),
                '","value":"',
                PunkSprites.accessoryName(accessories[i]),
                '"}'
            );
        }
        bytes memory json = abi.encodePacked(
            '{"name":"IMDPunk #',
            number.toString(),
            '","description":"',
            DESCRIPTION,
            '","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(imageOf(number))),
            '","attributes":[',
            attributes,
            ',{"trait_type":"Accessory count","value":',
            accessories.length.toString(),
            "}]}"
        );
        return string.concat("data:application/json;base64,", Base64.encode(json));
    }

    function _paint(bytes memory pixels, bytes memory data, bytes memory offsets, uint256 id) private pure {
        uint256 start = PunkSprites.offset(offsets, id);
        uint256 end = PunkSprites.offset(offsets, id + 1);
        for (uint256 i = start; i < end; i += 4) {
            uint256 at = uint8(data[i]) + uint256(uint8(data[i + 1])) * 24;
            uint256 stop = at + uint8(data[i + 2]);
            for (; at < stop; ++at) {
                pixels[at] = data[i + 3];
            }
        }
    }

    function _palette(uint256 number, PunkTraits.Kind t) private pure returns (bytes memory palette) {
        palette = PALETTE;
        bytes memory skin;
        if (t == PunkTraits.Kind.Alien) {
            skin = "#8bbeb5#5b918c#c2ddd0";
        } else if (t == PunkTraits.Kind.Ape) {
            skin = "#85694f#594c43#c1a17a";
        } else if (t == PunkTraits.Kind.Zombie) {
            skin = "#96a581#6c7b69#c2c7a0";
        } else {
            bytes memory tones = SKINS;
            uint256 tone = uint256(keccak256(abi.encode(number, uint256(2)))) % 6;
            skin = new bytes(21);
            for (uint256 i; i < 21; ++i) {
                skin[i] = tones[tone * 21 + i];
            }
        }
        for (uint256 i; i < 21; ++i) {
            palette[14 + i] = skin[i];
        }
    }

    function _rect(bytes memory out, uint256 at, uint256 x, uint256 y, uint256 w, bytes memory palette, uint256 c)
        private
        pure
        returns (uint256)
    {
        at = _append(out, at, '<rect x="');
        at = _number(out, at, x);
        at = _append(out, at, '" y="');
        at = _number(out, at, y);
        at = _append(out, at, '" width="');
        at = _number(out, at, w);
        at = _append(out, at, '" height="1" fill="');
        for (uint256 i; i < 7; ++i) {
            out[at++] = palette[c * 7 + i];
        }
        return _append(out, at, '"/>');
    }

    function _number(bytes memory out, uint256 at, uint256 n) private pure returns (uint256) {
        if (n >= 10) out[at++] = bytes1(uint8(48 + n / 10));
        out[at++] = bytes1(uint8(48 + n % 10));
        return at;
    }

    function _append(bytes memory out, uint256 at, bytes memory text) private pure returns (uint256) {
        // The final padded word is within the oversized output allocation.
        assembly ("memory-safe") {
            let length := mload(text)
            let dest := add(add(out, 32), at)
            for { let i := 0 } lt(i, length) { i := add(i, 32) } {
                mstore(add(dest, i), mload(add(add(text, 32), i)))
            }
        }
        return at + text.length;
    }
}
