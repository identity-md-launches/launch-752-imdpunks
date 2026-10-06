// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Immutable trait rules. Accessory ids 0..43 are Male; 44..86 are Female.
library PunkTraits {
    enum Kind {
        Alien,
        Ape,
        Zombie,
        Female,
        Male
    }
    error InvalidNumber();
    error InvalidAccessory();

    function kind(uint256 number) internal pure returns (Kind) {
        if (number >= 10_000) revert InvalidNumber();
        uint256 rank = (number * 7919 + 4321) % 10_000;
        if (rank < 9) return Kind.Alien;
        if (rank < 33) return Kind.Ape;
        if (rank < 121) return Kind.Zombie;
        if (rank < 3961) return Kind.Female;
        return Kind.Male;
    }

    function typeName(Kind t) internal pure returns (string memory) {
        if (t == Kind.Alien) return "Alien";
        if (t == Kind.Ape) return "Ape";
        if (t == Kind.Zombie) return "Zombie";
        if (t == Kind.Female) return "Female";
        return "Male";
    }

    function slotName(uint256 slot) internal pure returns (string memory) {
        if (slot == 0) return "Head";
        if (slot == 1) return "Eyes";
        if (slot == 2) return "Mouth";
        if (slot == 3) return "Facial hair";
        if (slot == 4) return "Ear";
        if (slot == 5) return "Neck";
        return "Face mark";
    }

    function count(uint256 seed) internal pure returns (uint256) {
        uint256 roll = seed % 10_000;
        if (roll < 10) return 0;
        if (roll < 310) return 1;
        if (roll < 3910) return 2;
        if (roll < 8410) return 3;
        if (roll < 9810) return 4;
        if (roll < 9980) return 5;
        if (roll < 9990) return 6;
        return 7;
    }

    function bounds(uint256 slot, bool female) internal pure returns (uint256 start, uint256 length) {
        if (slot == 0) return (female ? 44 : 0, 12);
        if (slot == 1) return (female ? 56 : 12, 8);
        if (slot == 2) return (female ? 64 : 20, 5);
        if (slot == 3) return (female ? 69 : 25, female ? 5 : 6);
        if (slot == 4) return (female ? 74 : 31, 4);
        if (slot == 5) return (female ? 78 : 35, 5);
        return (female ? 83 : 40, 4);
    }

    function info(uint256 id) internal pure returns (uint8 slot, bool female) {
        if (id >= 87) revert InvalidAccessory();
        female = id >= 44;
        for (uint8 s; s < 7; ++s) {
            (uint256 start, uint256 length) = bounds(s, female);
            if (id >= start && id < start + length) return (s, female);
        }
        revert InvalidAccessory();
    }

    /// @dev Partial Fisher-Yates selects unique slots; all entropy depends only on the number.
    function accessories(uint256 number) internal pure returns (uint8[] memory ids) {
        bool female = kind(number) == Kind.Female;
        uint256 n = count(uint256(keccak256(abi.encode(number))));
        ids = new uint8[](n);
        uint8[7] memory slots = [0, 1, 2, 3, 4, 5, 6];
        uint8[7] memory selected;
        for (uint256 i; i < n; ++i) {
            uint256 random = uint256(keccak256(abi.encode(number, i, uint256(1))));
            uint256 pick = i + random % (7 - i);
            uint8 slot = slots[pick];
            slots[pick] = slots[i];
            (uint256 start, uint256 length) = bounds(slot, female);
            selected[slot] = uint8(start + (random / 7) % length + 1);
        }
        uint256 at;
        for (uint256 slot; slot < 7; ++slot) {
            if (selected[slot] != 0) ids[at++] = selected[slot] - 1;
        }
    }
}
