// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev Independent, strict parsers for the exact data URI and run-rectangle SVG formats.
library RenderChecks {
    function strip(bytes memory data, bytes memory prefix) internal pure returns (bytes memory result) {
        uint256 at = expect(data, 0, prefix);
        result = new bytes(data.length - at);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[at + i];
        }
    }

    function decode64(bytes memory data) internal pure returns (bytes memory result) {
        require(data.length > 0 && data.length % 4 == 0, "base64 length");
        uint256 padding = data[data.length - 1] == "=" ? 1 : 0;
        if (data[data.length - 2] == "=") ++padding;
        result = new bytes(data.length / 4 * 3 - padding);
        uint256 at;
        for (uint256 i; i < data.length; i += 4) {
            uint256 word;
            for (uint256 j; j < 4; ++j) {
                uint256 c = uint8(data[i + j]);
                uint256 v;
                if (c >= 65 && c <= 90) v = c - 65;
                else if (c >= 97 && c <= 122) v = c - 71;
                else if (c >= 48 && c <= 57) v = c + 4;
                else if (c == 43) v = 62;
                else if (c == 47) v = 63;
                else require(c == 61 && i + j >= data.length - padding, "base64 alphabet");
                word = (word << 6) | v;
            }
            for (uint256 j; j < 3; ++j) {
                if (at < result.length) result[at++] = bytes1(uint8(word >> (16 - 8 * j)));
            }
            if (i + 4 == data.length && padding != 0) {
                require(word & ((uint256(1) << (padding * 8)) - 1) == 0, "noncanonical base64 padding");
            }
        }
    }

    function expect(bytes memory data, uint256 at, bytes memory literal) internal pure returns (uint256) {
        require(at + literal.length <= data.length, "truncated output");
        for (uint256 i; i < literal.length; ++i) {
            require(data[at + i] == literal[i], "invalid output syntax");
        }
        return at + literal.length;
    }

    function decimal(bytes memory data, uint256 at) private pure returns (uint256 value, uint256 next) {
        uint256 start = at;
        while (at < data.length && data[at] >= "0" && data[at] <= "9") {
            value = value * 10 + uint8(data[at++]) - 48;
        }
        require(at > start && at - start <= 2 && value < 25, "invalid coordinate");
        return (value, at);
    }

    function rect(bytes memory data, uint256 at)
        private
        pure
        returns (uint256 x, uint256 y, uint256 w, bytes32 color, uint256 next)
    {
        at = expect(data, at, '<rect x="');
        (x, at) = decimal(data, at);
        at = expect(data, at, '" y="');
        (y, at) = decimal(data, at);
        at = expect(data, at, '" width="');
        (w, at) = decimal(data, at);
        at = expect(data, at, '" height="1" fill="#');
        for (uint256 i; i < 6; ++i) {
            bytes1 c = data[at + i];
            require((c >= "0" && c <= "9") || (c >= "a" && c <= "f"), "invalid SVG colour");
            color |= bytes32(c) >> (i * 8);
        }
        next = expect(data, at + 6, '"/>');
    }

    /// @dev Parses every byte, checks colour syntax, all 576 pixels and canonical maximal horizontal runs.
    function svg(bytes memory data) internal pure {
        uint256 at = expect(
            data, 0, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" shape-rendering="crispEdges">'
        );
        uint256 expectedX;
        uint256 expectedY;
        uint256 rects;
        uint256 facePixels;
        bytes32 background;
        bytes32 previous;
        while (expectedY < 24) {
            (uint256 x, uint256 y, uint256 w, bytes32 color, uint256 next) = rect(data, at);
            at = next;
            require(x == expectedX && y == expectedY && w > 0 && x + w <= 24, "pixel coverage");
            if (rects == 0) background = color;
            if (x != 0) require(color != previous, "non-maximal run");
            if (y >= 5 && y <= 18 && color != background) facePixels += w;
            if (x == 0 || x + w == 24) require(color == background, "background must be flat");
            previous = color;
            expectedX += w;
            if (expectedX == 24) {
                expectedX = 0;
                ++expectedY;
            }
            ++rects;
        }
        at = expect(data, at, "</svg>");
        require(at == data.length && rects >= 60 && facePixels >= 90, "incomplete portrait");
    }
}
