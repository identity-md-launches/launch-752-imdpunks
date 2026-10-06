# IMDPunks

An immutable ERC-721 collection of 10,000 original 24 × 24 pixel portraits. Collection name **IMDPunks**, symbol **IMDPUNK**. All drawings, traits, SVG rendering and JSON metadata live in deployed bytecode. There are no remote assets or services to maintain.

## Build and test

Requires Foundry and Solidity **0.8.26**. The configuration pins that version, targets Paris, enables the optimizer at 200 runs, and sets `bytecode_hash = "none"`. Dependencies are ordinary vendored files; no downloads, submodules, npm packages, environment configuration, FFI or filesystem cheatcodes are needed by the build/tests once the compiler is installed.

```sh
forge build
forge test
forge fmt --check
```

The suite has 31 tests, including two fuzz tests with 256 runs each. It exhaustively counts the types and validates accessory compatibility for all 10,000 numbers, claims all 9,800 publicly available tokens, transfers all 200 reserved tokens out and back, and parses metadata for more than 200 distinct numbers. Samples include 0, 777, 888, 9999, every type and every accessory count from zero through seven. JSON is decoded and parsed independently; SVG validation parses every rectangle and checks complete coverage of the 576-pixel canvas, coordinates, colours and maximal horizontal runs. Claim and transfer callback attacks, failed receiver rollback, approvals, ETH rejection and invalid inputs are exercised.

## Deployment

Deploy **`src/IMDPunks.sol:IMDPunks`** with exactly one constructor argument:

| Position | Solidity type | Value |
| --- | --- | --- |
| 0 | `address` | `0x2E28b29560a6d4812E58680484c685D0352f8ff9` |

Send zero ETH. `launch.json` supplies these factory-compatible parameters. The constructor creates its own **IMDPunksArt** renderer; do not deploy or configure a separate renderer. The renderer address is available through `art()` and cannot change. There are no initialization calls. A factory may be the deployer: `msg.sender` receives no allocation or authority.

Native CREATE2 in the test measures **4,441,892 gas**, including the internal renderer deployment and reserve. A conservative allowance for transaction calldata, base gas and factory hashing brings this to **4,793,876 gas**, below 10,000,000. A separate local Anvil creation transaction used **4,780,738 gas**. Factory-specific overhead is additional and should be checked by the deployment service. Runtime sizes are **6,050 bytes** for IMDPunks and **13,334 bytes** for IMDPunksArt, both below 24,576 bytes; main initcode including arguments is **20,368 bytes**.

The launch operator must preserve the constructor beneficiary and compiler settings, simulate the actual factory transaction with its gas ceiling, verify both contracts' source, and record the confirmed collection and `art()` addresses. This project does not select a chain, broadcast a live transaction, or require a funded key. No ongoing administrator, keeper or asset host is needed. The reserve wallet is responsible for its own key custody.

## Ownership and claims

At deployment, ids **0–197, 777 and 888** belong to the configured reserve. Each emits its own ordinary `Transfer(0, reserve, id)` event. `totalSupply()` begins at 200 and its balance begins at 200. To avoid 200 storage writes, `_ownerOf` returns the immutable reserve for these ids until their first transfer. OpenZeppelin's normal transfer logic then records their explicit owner, clears approvals and adjusts balances. There is no burn entry point, so a transferred reserve token can never fall back to its initial owner.

`claim(number)` is nonpayable and mints that exact available number to the caller. Each address can successfully claim at most five times in its lifetime. Transfers in or out and the initial reserve do not consume or restore claims. Claims deliberately use `_mint`: there is no receiver callback on a claim, and contracts claiming must be able to manage their NFTs themselves. `safeTransferFrom` performs the normal ERC-721 receiver check after state changes.

Every token has identical transfer rules, with no fees or transfer limits. There is no owner role, admin, allowlist, pause, upgrade, royalty, withdrawal, extra mint or burn path. The contracts reject ordinary ETH transfers and value-bearing calls. As with any EVM contract, protocol-forced ETH cannot be prevented; it confers no rights and cannot be withdrawn.

The claim limit is per **address**, not per person; using multiple addresses is possible. Numbers and traits are public before claiming, so claimants can choose traits and competing claims can be reordered. This is intentional and is not a random sale or fairness mechanism.

## Public queries

| Query | Behaviour |
| --- | --- |
| `totalSupply()` | Number already issued, including reserve; maximum 10,000 |
| `MAX_SUPPLY()` | Constant 10,000 |
| `isMinted(number)` | Whether the number exists; false for any out-of-range number |
| `claimedBy(account)` | Successful public claims by that address, permanently 0–5 |
| `typeOf(number)` | Enum ABI `uint8`: 0 Alien, 1 Ape, 2 Zombie, 3 Female, 4 Male |
| `accessoriesOf(number)` | Accessory ids, in slot order; works before minting |
| `imageOf(number)` | Raw SVG for any number 0–9999, whether minted or not |
| `tokenURI(number)` | Base64 JSON with nested base64 SVG, only for minted tokens |
| `art().accessoryInfo(id)` | `(name, slot, femaleSet)` for accessory ids 0–86 |

Trait and image queries reject numbers at or above 10,000. `tokenURI`, `ownerOf` and `getApproved` reject nonexistent tokens. ERC-165, ERC-721 and ERC-721 metadata interfaces are supported; full enumerable and royalty interfaces are not advertised. The renderer's `metadata(number)` is a pure preview for every valid number; the collection's `tokenURI` enforces token existence.

## Artwork and exact trait rules

The five base heads and **87 distinct accessories** were drawn for this project. All 87 are reachable. The Male set has 44 accessories; the Female set has 43. Alien, Ape and Zombie use the Male set. Female has her own drawings, including fine facial-hair variants. Human skin is selected from six three-colour palettes. Rare types have distinct silhouettes and palettes. The background is one flat colour. Pixels are composited first and emitted as one `<rect height="1">` per maximal horizontal run, under `viewBox="0 0 24 24"` and `shape-rendering="crispEdges"`.

`rank = (number * 7919 + 4321) % 10000` is a permutation. No hash determines the type:

| Rank | Type | Exact total |
| --- | --- | ---: |
| 0–8 | Alien | 9 |
| 9–32 | Ape | 24 |
| 33–120 | Zombie | 88 |
| 121–3960 | Female | 3,840 |
| 3961–9999 | Male | 6,039 |

The count roll is `uint256(keccak256(abi.encode(number))) % 10000`. Cumulative thresholds are 10, 310, 3910, 8410, 9810, 9980 and 9990, with the remaining rolls producing seven accessories. Partial Fisher–Yates selection chooses distinct slots using `keccak256(abi.encode(number, i, uint256(1)))`. Variants come only from that type's slot range. Skin uses a separate number-derived hash. No block, sender, ownership or external state affects art.

| Accessories | Target proportion | Actual over all 10,000 |
| ---: | ---: | ---: |
| 0 | 0.1% | 8 |
| 1 | 3% | 289 |
| 2 | 36% | 3,610 |
| 3 | 45% | 4,505 |
| 4 | 14% | 1,408 |
| 5 | 1.7% | 161 |
| 6 | 0.1% | 11 |
| 7 | 0.1% | 8 |

Slots 0–6 are head, eyes, mouth, facial hair, ear, neck and face mark. The catalogue is in [`tools/accessories.json`](tools/accessories.json). The original drawing source is [`tools/generate_art.py`](tools/generate_art.py); it needs only Python's standard library. Running it regenerates `src/PunkSprites.sol` and the catalogue; run `forge fmt` afterward. Neither Python nor these development files is needed at runtime. Sprite offsets use two base-128 digits to keep packed data compatible with the launch's conservative bytecode scan.

Metadata names are `IMDPunk #<number>`, with a one-line description, Type, one attribute per accessory (slot as `trait_type`, accessory name as `value`), and a numeric Accessory count. Input numbers are converted only to decimal; all other text is fixed ASCII. There are no editable strings or URI setters.

## Dependencies and review

- OpenZeppelin Contracts **v5.0.2**, MIT: the required ERC-721, Base64, Strings and transitive sources are vendored in `lib/openzeppelin-contracts/`.
- forge-std **v1.9.7**, MIT / Apache-2.0: test sources and licences are vendored in `lib/forge-std/`.

The adversarial review and evidence are recorded in [`REVIEW.md`](REVIEW.md). Foundry tests and a local Anvil rehearsal were run. Slither and Mythril were not run. These checks are local implementation evidence, not an independent security audit.
