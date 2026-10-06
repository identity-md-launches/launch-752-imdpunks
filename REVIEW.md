# Local adversarial review

Scope: IMDPunks, IMDPunksArt, PunkTraits and the generated sprite data, with OpenZeppelin v5.0.2 ERC-721 transfer machinery. The pinned security reference was reviewed as background. No funds, oracle, signature, proxy, external asset URI or administrative subsystem exists.

| Attempt | Evidence and result |
| --- | --- |
| Mint more than 10,000 | Every id outside 0–9999 fails before state updates. The exhaustive supply test issues all 9,800 public ids through 1,960 addresses and finishes at 10,000 including reserve. Further claims of unavailable and out-of-range ids fail. |
| Mint the same number twice | `isMinted` checks both explicit and implicit owners. Repeated claims, transferred numbers and all 200 reserve ids are rejected. Fuzz tests vary public ids and claimants. |
| Reset the lifetime allowance | Successful claims increment a separate counter. Sending away all five NFTs leaves the counter at five; receiving five NFTs leaves it at zero. Failed claims do not increment it. |
| Reenter through mint receiver | Claim updates its counter and supply and uses `_mint`, with no external callback. A receiver's direct claim triggers zero callbacks. |
| Reenter through safe transfer | The malicious receiver attempts a duplicate claim, theft of another reserve NFT, six new claims and an onward transfer. Only its remaining four permitted claims succeed, the duplicate and theft fail, and the onward transfer preserves ownership and balances. |
| Corrupt first reserve transfer | All 200 reserve NFTs are transferred out and back. Each step checks owners and balances. Old reserve ownership cannot be used to authorize a second transfer after the explicit owner changes. No external burn path can restore the fallback. |
| Reject a reserve safe transfer | A bad receiver selector or a receiver without the interface reverts the whole transfer, restoring implicit ownership, balances and the prior token approval. |
| Abuse approvals | Unauthorized transfer, stale approval, revoked operator, incorrect `from`, self-transfer and zero receiver are exercised. Normal approved transfers clear token approval. |
| Break metadata or rendering | More than 200 distinct samples include every type, every accessory count and required boundary/reserve ids. Independent base64 decoding, Foundry JSON parsing and a strict SVG grammar validate the outputs. Minting, transfers and block changes leave art and metadata unchanged. Unminted and out-of-range URI requests revert. |
| Break accessory compatibility | All 10,000 selections have unique slots and the correct set. All 87 names and all 92 base/accessory sprites are distinct. All sprite runs are bounded to the canvas and palette. |
| Change supply, art or privileges | No externally exposed burn, other mint, setter, admin, upgrade or pause exists. The renderer is created from fixed code, with its address immutable. Both runtime bytecodes pass the same conservative forbidden-opcode scan as the protected harness. |
| Send ETH or exceed deployment limits | Plain and value-bearing claim calls fail. Native CREATE2 deployment including renderer and reserve stays below the 10 million gas ceiling, including a conservative transaction allowance. Both runtimes fit EIP-170 and collection initcode fits EIP-3860. |

The `_ownerOf` override is paired with `_increaseBalance(reserve, 200)` in the constructor, as required by OpenZeppelin's extension mechanism. Subsequent transfers use the unmodified OpenZeppelin `_update` bookkeeping. The supply cap follows from a bounded number universe, pre-existing reserve ids, absence of burns and single issuance per id.

The renderer's only assembly helper copies strings into a 40,000-byte output allocation and truncates its logical length at completion. Its inputs are fixed renderer fragments. At most 576 runs of at most 59 bytes, the 83-byte header and six-byte footer fit comfortably, including the final padded word. Every sprite run, palette index and final output is tested. JSON concatenation does not hash ambiguous dynamic fields and has no user-provided text requiring escaping.

The final standard suite has 31 passing tests with 256 runs for each of two fuzz tests. A separate local Anvil rehearsal deployed the actual initcode, measured 4,780,738 transaction gas, and rendered 20 portraits for visual inspection, including all five types. Faces, necks and backgrounds were complete. This rehearsal was local only. No independent contributor audit, Slither or Mythril run is claimed.

Residual operational assumptions: the deployment manifest must retain the requested reserve wallet; its key custody belongs to its holder; the launch service must simulate its actual factory overhead; callers pay network gas; per-address limits cannot enforce per-person limits. Ordinary ETH is rejected, but protocol-forced ETH cannot be refused or recovered. A contract using `claim` must itself support managing the token because the mint intentionally has no receiver acceptance callback.
