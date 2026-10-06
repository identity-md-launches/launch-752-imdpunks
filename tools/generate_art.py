#!/usr/bin/env python3
"""Original IMDPunks pixel drawings. Standard library only; regenerates the Solidity sprite library.
Each authored sprite is flattened into horizontal runs (x, y, length, palette index).
The generator is a development aid: deployment and rendering use only the committed Solidity.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
sprites, names, catalog = [], [], []
INK, SKIN, SHADE, LIGHT, EYE, SHIRT = 1, 2, 3, 4, 5, 6
GOLD, CORAL, TEAL, BLUE, LILAC, WHITE, ROSE, OLIVE = 8, 9, 10, 11, 12, 13, 14, 15

class Drawing:
    def __init__(self): self.p = [[-1] * 24 for _ in range(24)]
    def r(self, x, y, w, h, c):
        assert 0 <= x < x+w <= 24 and 0 <= y < y+h <= 24
        for yy in range(y,y+h):
            for xx in range(x,x+w): self.p[yy][xx] = c
    def runs(self):
        out = bytearray()
        for y,row in enumerate(self.p):
            x = 0
            while x < 24:
                c = row[x]; end = x+1
                while end < 24 and row[end] == c: end += 1
                if c >= 0: out.extend((x,y,end-x,c))
                x = end
        return out

def base(kind):
    d = Drawing(); r = d.r
    # Stepped shoulders, an open collar and a three-pixel neck.
    r(6,22,13,2,INK); r(8,21,9,2,INK); r(7,23,11,1,SHIRT)
    r(9,22,7,2,SHIRT); r(10,18,5,4,INK); r(11,18,3,4,SKIN); r(13,19,1,2,SHADE)
    if kind == 0:  # Split-level luminous forehead and long, tapering jaw.
        for x,y,w,h in [(9,3,7,1),(7,4,11,2),(6,6,13,6),(7,12,11,3),(8,15,9,2),(10,17,5,2)]: r(x,y,w,h,INK)
        for x,y,w,h in [(9,4,7,1),(8,5,9,2),(7,7,11,5),(8,12,9,3),(9,15,7,2),(11,17,3,1)]: r(x,y,w,h,SKIN)
        r(8,6,3,2,LIGHT); r(16,7,2,5,SHADE); r(15,12,2,3,SHADE)
        r(8,10,3,2,INK); r(14,10,3,2,INK); r(9,10,1,1,EYE); r(15,10,1,1,EYE)
        r(12,12,1,2,SHADE); r(11,15,3,1,INK)
    elif kind == 1:  # Wide temples, brow ridge, separate tan muzzle.
        r(8,5,9,2,INK); r(6,7,13,8,INK); r(5,10,15,4,INK); r(7,15,11,3,INK); r(9,18,7,1,INK)
        r(8,6,9,1,SKIN); r(7,8,11,7,SKIN); r(6,11,13,2,SKIN); r(8,15,9,2,SKIN)
        r(8,8,9,2,SHADE); r(8,10,3,2,INK); r(14,10,3,2,INK); r(9,10,1,1,EYE); r(15,10,1,1,EYE)
        r(9,13,7,4,LIGHT); r(10,12,5,2,LIGHT); r(11,13,3,1,INK); r(10,16,5,1,INK)
        r(17,9,1,5,SHADE); r(9,17,7,1,SHADE)
    elif kind == 2:  # Staggered hairline and weathered mosaic skin.
        r(8,5,7,1,INK); r(7,6,11,3,INK); r(6,9,13,6,INK); r(7,15,11,3,INK); r(9,18,7,1,INK)
        r(8,7,9,2,SKIN); r(7,9,11,6,SKIN); r(8,15,9,2,SKIN); r(10,17,5,1,SKIN)
        r(8,7,3,2,LIGHT); r(15,8,2,3,SHADE); r(7,12,2,3,SHADE); r(15,15,2,2,SHADE)
        r(8,10,3,2,INK); r(14,10,3,1,INK); r(9,10,1,1,GOLD); r(15,10,1,1,EYE)
        r(12,12,1,2,SHADE); r(10,15,5,1,INK); r(11,15,1,1,EYE); r(14,16,1,1,INK)
    elif kind == 3:  # Narrow jaw, asymmetric curls at the temples.
        r(9,5,7,1,INK); r(7,6,11,4,INK); r(6,10,13,4,INK); r(7,14,11,3,INK); r(9,17,7,2,INK)
        r(9,6,7,1,SKIN); r(8,7,9,3,SKIN); r(7,10,11,4,SKIN); r(8,14,9,3,SKIN); r(10,17,5,1,SKIN)
        r(8,7,2,2,LIGHT); r(16,9,1,6,SHADE); r(14,16,2,1,SHADE)
        r(7,6,2,4,7); r(16,6,2,3,7); r(17,8,1,3,7)
        r(8,10,3,1,INK); r(14,10,3,1,INK); r(9,11,1,1,EYE); r(15,11,1,1,EYE)
        r(12,12,1,2,SHADE); r(11,15,3,1,INK); r(12,16,2,1,SHADE)
    else:  # Broad jaw, swept hairline and off-centre highlight.
        r(8,5,9,1,INK); r(7,6,11,4,INK); r(6,10,13,4,INK); r(7,14,11,4,INK); r(9,18,7,1,INK)
        r(8,6,9,3,SKIN); r(7,9,11,5,SKIN); r(8,14,9,3,SKIN); r(10,17,5,1,SKIN)
        r(8,6,8,1,7); r(7,7,2,2,7); r(8,8,2,1,LIGHT); r(16,9,1,7,SHADE)
        r(8,10,3,1,INK); r(14,10,3,1,INK); r(9,11,1,1,EYE); r(15,11,1,1,EYE)
        r(12,12,1,2,SHADE); r(10,15,5,1,INK); r(11,17,3,1,SHADE)
    return d

MALE = [
 ['Signal Crest','Tidal Fold','Ember Part','Orbit Brim','Kiln Wrap','Copper Sprouts','Harbor Roof','Lattice Crown','Cobalt Wave','Dune Roll','Moss Peak','Night Antenna'],
 ['Amber Bridges','Split Prism','Wave Readers','Bolt Lenses','Cloud Shields','Dusk Frames','Thread Monocle','Teal Browbar'],
 ['Coral Grin','Silver Toothline','Mint Stem','Pebble Lip','Ochre Breath'],
 ['Cinder Jaw','Twin Stubble','Rust Chevron','Coal Crescent','Walnut Fork','Slate Whiskers'],
 ['Signal Stud','Copper Ladder','Tidal Hook','Azure Pin'],
 ['Saffron Loop','Harbor Collar','Brick Kerchief','Orbit Beads','Iris Clasp'],
 ['Dawn Steps','Circuit Cheek','Tide Dashes','Ember Mosaic']]
FEMALE = [
 ['Petal Turret','Ribbon Shoal','Indigo Fan','Sunrise Fold','Pearl Canopy','Willow Combs','Rose Switchback','Lagoon Halo','Marigold Sweep','Velvet Arches','Opal Ladder','Twilight Spire'],
 ['Petal Bridges','Rose Prisms','Lagoon Readers','Starling Lenses','Lilac Shields','Sunlit Frames','Pearl Monocle','Iris Browbar'],
 ['Berry Smile','Opal Toothline','Clover Stem','Garnet Lip','Apricot Breath'],
 ['Velvet Wisp','Copper Chin Arc','Lilac Sideburns','Sable Chin Tuft','Rose Jaw Fringe'],
 ['Petal Stud','Opal Ladder Drop','Lagoon Hook','Rose Pin'],
 ['Iris Loop','Petal Collar','Lagoon Kerchief','Dawn Beads','Opal Clasp'],
 ['Petal Steps','Starling Cheek','Dawn Dashes','Opal Mosaic']]

def accessory(slot, v, female):
    d=Drawing(); r=d.r
    a = [TEAL,GOLD,CORAL,BLUE,OLIVE,LILAC][v%6]
    b = [LILAC,CORAL,TEAL,GOLD,ROSE,WHITE][v%6]
    if female: a,b = b,a
    # Every branch is an authored silhouette; Female variants alter both pixels and colours.
    if slot == 0:
        if v == 0:
            r(8,5,9,2,INK); r(9,4,7,2,a); r(11,2,3,3,a); r(12,1,1,2,b)
        elif v == 1:
            r(6,6,13,2,INK); r(7,5,11,2,a); r(9,4,7,1,a); r(8,6,8,1,b)
        elif v == 2:
            r(7,5,11,2,a); r(8,4,8,2,a); r(9,3,3,2,b); r(7,6,2,3,a); r(14,5,3,1,b)
        elif v == 3:
            r(5,7,15,1,INK); r(8,3,9,4,INK); r(9,4,7,3,a); r(9,6,7,1,b)
        elif v == 4:
            r(7,4,11,4,INK); r(8,4,9,3,a); r(7,6,11,1,b); r(16,7,2,3,a)
        elif v == 5:
            r(8,5,9,2,a); r(8,3,2,3,a); r(12,2,2,4,b); r(16,3,2,3,a)
        elif v == 6:
            r(6,6,14,2,INK); r(8,4,9,2,INK); r(9,4,7,3,a); r(7,6,11,1,a); r(16,7,4,1,b)
        elif v == 7:
            r(7,5,11,2,a); r(7,3,2,3,a); r(11,2,2,4,a); r(16,3,2,3,a); r(9,5,1,1,b); r(14,5,1,1,b)
        elif v == 8:
            r(7,5,11,2,a); r(9,4,9,2,a); r(13,3,5,2,b); r(17,5,2,4,a)
        elif v == 9:
            r(7,4,11,4,INK); r(8,4,9,3,a); r(6,7,13,1,b); r(9,5,6,1,b)
        elif v == 10:
            r(8,5,9,2,a); r(9,4,7,2,a); r(10,3,5,2,a); r(11,2,3,2,b)
        else:
            r(7,6,11,1,a); r(8,2,1,4,INK); r(7,1,3,2,b); r(16,3,1,3,INK); r(15,2,3,2,a)
        if female:
            r(6,7,1,3,a); r(5,9,2,2,a); r(17,7,1,2,b)
    elif slot == 1:
        if v < 2:
            r(7,9,5,3,INK); r(13,9,5,3,INK); r(12,10,1,1,INK)
            r(8,10,3,1,a); r(14,10,3,1,a); r(8+v,10,1,1,b); r(15+v,10,1,1,b)
            if v == 1: r(7,8,2,1,a); r(16,8,2,1,a)
        elif v == 2:
            r(7,10,5,3,a); r(13,10,5,3,a); r(12,10,1,1,a); r(8,11,3,1,EYE); r(14,11,3,1,EYE)
        elif v == 3:
            r(7,9,5,2,a); r(13,10,5,2,a); r(9,11,3,1,b); r(13,9,3,1,b)
        elif v == 4:
            r(7,9,11,3,INK); r(8,10,9,1,a); r(9,10,2,1,b); r(15,10,1,1,b)
        elif v == 5:
            r(7,9,5,3,a); r(13,9,5,3,a); r(8,10,3,1,INK); r(14,10,3,1,INK); r(12,10,1,1,b)
        elif v == 6:
            r(13,9,5,3,a); r(14,10,3,1,EYE); r(17,12,1,3,b)
        else:
            r(7,9,11,1,a); r(8,10,3,1,b); r(14,10,3,1,b)
        if female: r(6,9,1,1,b); r(18,9,1,1,b)
    elif slot == 2:
        if v == 0: r(10,15,5,1,a); r(11,16,3,1,b)
        elif v == 1: r(10,15,5,1,INK); r(11,15,1,1,b); r(13,15,1,1,WHITE)
        elif v == 2: r(14,15,5,1,OLIVE); r(18,14,2,1,a); r(19,13,1,1,b)
        elif v == 3: r(11,15,3,2,a); r(12,15,2,1,b)
        else: r(14,15,3,1,a); r(17,14,1,1,b); r(18,13,1,1,b)
        if female: r(10,15,1,1,ROSE)
    elif slot == 3:
        hair = [7,16,21,1,17,23][v]
        if v == 0: r(8,16,2,2,hair); r(9,18,7,1,hair); r(15,16,2,2,hair)
        elif v == 1: r(9,17,1,1,hair); r(11,18,1,1,hair); r(13,18,1,1,hair); r(15,17,1,1,hair)
        elif v == 2: r(9,14,3,1,hair); r(13,14,3,1,hair); r(8,15,2,1,hair); r(15,15,2,1,hair)
        elif v == 3: r(10,17,5,1,hair); r(11,18,3,1,hair)
        elif v == 4: r(10,17,5,1,hair); r(10,18,2,2,hair); r(13,18,2,2,hair)
        else: r(7,13,2,3,hair); r(16,13,2,3,hair); r(8,16,2,1,hair); r(15,16,2,1,hair)
        if female:
            # Fine hairs: retain the shape but break the heavy line into individual pixels.
            for y in range(24):
                for x in range(24):
                    if d.p[y][x] >= 0 and (x+y)%2 == 0: d.p[y][x] = -1
            r(10+v,18,1,1,a)
    elif slot == 4:
        x = 6 if female else 18
        if v == 0: r(x,12,1,1,a); r(x,13,1,1,b)
        elif v == 1: r(x,12,1,4,a); r(x,13,2,1,b); r(x,15,2,1,b)
        elif v == 2: r(x,12,2,3,a); r(x,12,1,2,0); r(x,14,1,1,b)
        else: r(x,11,1,3,a); r(x,12,2,1,b)
    elif slot == 5:
        if v == 0: r(10,20,5,1,a); r(11,21,3,1,a); r(12,21,1,1,b)
        elif v == 1: r(8,21,3,2,a); r(14,21,3,2,a); r(10,22,1,1,b); r(14,22,1,1,b)
        elif v == 2: r(9,20,7,1,a); r(10,21,5,1,a); r(11,22,3,1,b); r(12,23,1,1,b)
        elif v == 3:
            for x,y in [(9,20),(10,21),(12,22),(14,21),(15,20)]: r(x,y,1,1,a)
            r(12,22,1,1,b)
        else: r(10,21,5,1,a); r(11,22,3,1,b); r(12,21,1,2,WHITE)
        if female: r(8,22,1,1,b); r(16,22,1,1,b)
    else:
        x = 8 if female else 15
        if v == 0: r(x,12,1,1,a); r(x+1,13,1,1,a); r(x,14,1,1,b)
        elif v == 1: r(x,12,2,1,a); r(x+1,13,1,2,a); r(x,14,1,1,b)
        elif v == 2: r(x,12,2,1,a); r(x,14,2,1,b)
        else: r(x,12,1,1,a); r(x+1,13,1,1,b); r(x,14,1,1,WHITE)
    return d

for t in range(5): sprites.append(base(t))
for female, groups in [(False,MALE),(True,FEMALE)]:
    for slot, group in enumerate(groups):
        for variant, name in enumerate(group):
            sprites.append(accessory(slot,variant,female)); names.append(name)
            catalog.append({'id':len(names)-1,'name':name,'slot':slot,'set':'Female' if female else 'Male'})
assert len(names) == 87 and len(set(names)) == 87
runs=bytearray(); offsets=bytearray()
for sprite in sprites:
    offsets.extend(bytes((len(runs)//128,len(runs)%128))); runs.extend(sprite.runs())
offsets.extend(bytes((len(runs)//128,len(runs)%128)))
name_data=bytearray(); name_offsets=bytearray()
for name in names:
    name_offsets.extend(bytes((len(name_data)//128,len(name_data)%128))); name_data.extend(name.encode())
name_offsets.extend(bytes((len(name_data)//128,len(name_data)%128)))
source = '''// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Generated by tools/generate_art.py from original drawings. No runtime off-chain dependency.
library PunkSprites {
    bytes internal constant RUNS = hex"%s";
    bytes internal constant OFFSETS = hex"%s";
    bytes internal constant NAMES = "%s";
    bytes internal constant NAME_OFFSETS = hex"%s";

    function offset(bytes memory table, uint256 index) internal pure returns (uint256) {
        return uint256(uint8(table[index * 2])) * 128 + uint8(table[index * 2 + 1]);
    }

    function accessoryName(uint256 id) internal pure returns (string memory) {
        bytes memory data = NAMES;
        bytes memory table = NAME_OFFSETS;
        uint256 start = offset(table, id);
        uint256 end = offset(table, id + 1);
        bytes memory result = new bytes(end - start);
        for (uint256 i; i < result.length; ++i) result[i] = data[start + i];
        return string(result);
    }
}
''' % (runs.hex(),offsets.hex(),name_data.decode(),name_offsets.hex())
(ROOT/'src/PunkSprites.sol').write_text(source)
(ROOT/'tools/accessories.json').write_text(json.dumps(catalog,indent=2)+'\n')
print(f'{len(sprites)} sprites, {len(runs)} run bytes, {len(names)} accessories')
