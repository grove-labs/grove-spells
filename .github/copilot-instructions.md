# Copilot review instructions for grove-spells

This repository holds Grove governance spells: one-shot Solidity payloads executed by the Grove
StarGuard on Ethereum mainnet (and relayed to foreign chains), plus a Foundry fork-test harness
that proves each payload does what its PR description says. Review with that purpose in mind:
the highest-value finding is a mismatch between the description, the payload, and the tests.

This file holds the code-level standards, which apply to every review. The review *process* — how to
tell which stage a spell PR has reached and how to word the verdict — is in the `code-review` skill at
`.github/skills/code-review/SKILL.md`. Follow it whenever you review a spell PR.

One rule from it is absolute enough to repeat here: **a spell PR merges only after the spell has
executed on-chain, four days after the date in its title.** Never choose `🟢 Approval recommended` on
one before that date, and never write "good to merge", "ready to merge" or "LGTM". No number of
reviewer sign-offs makes it mergeable earlier.

## Repository layout and PR types

- `src/proposals/<YYYYMMDD>/` holds the one spell currently in flight: `GroveEthereum_<d>.sol`,
  optional `Grove<Chain>_<d>.sol` foreign payloads, and `GroveEthereum_<d>.t.sol`. The matching
  `<d>.md` is git-ignored on purpose; it becomes the PR body.
- `archive/<YYYYMMDD>/` holds every executed spell, byte-identical to what shipped, plus the final
  PR body as `<d>.md`. Files under `archive/` are frozen. Do not suggest changes to them.
- `src/libraries/` holds the shared payload bases and helpers (`GrovePayloadEthereum`,
  `GrovePauHelpers`, `GroveLiquidityLayerHelpers`). `src/test-harness/` holds the fork-test
  runner and shared test bases.
- Three PR shapes recur:
  - **Spell PR**, title `<emoji> <Month> <D>, <YYYY> Spell`: adds `src/proposals/<d>/` (normally
    exactly the `.sol` files). Reviewed for correctness against the description.
  - **Archive PR**, title `<emoji> Archive <YYYYMMDD> Spell`: moves `src/proposals/<d>/` to
    `archive/<d>/` unchanged, bumps `lib/grove-address-registry` and `lib/spark-address-registry`
    with matching `foundry.lock` entries, and swaps hardcoded address literals in the harness for
    registry constants. All of that is routine.
  - **Infra PR**: changes to `src/libraries/`, `src/test-harness/`, CI, or docs. Review as
    ordinary Solidity/Foundry code; this is where deeper analysis pays off.

## What to check in a spell PR

1. **Description vs code.** Every amount, rate limit, slope, exchange rate, and address in the PR
   body's "List of intended changes" must appear as a literal or registry constant in the payload,
   and every payload action must be listed in the body. Flag anything present in one and missing
   from the other. Precision suffixes matter: `20_000_000e6` for USDC, `e18` for USDS.
2. **Tests cover each item.** Each helper subfunction called from `_execute()` / `execute()` has
   at least one test that executes the payload and asserts the post-state. A payload change with
   no test assertion is a finding.
3. **`BEFORE:` comments.** Every numeric argument at a helper call site carries a `// BEFORE: <x>`
   comment with the current on-chain value. Missing or implausible BEFORE values are findings.
4. **Hidden helper writes are documented.** Some helpers write more than their arguments show:
   `_setBasinPauRateLimits` also sets both `LIMIT_BASIN_WITHDRAW` keys unlimited;
   `_onboardERC4626Vault` also sets `LIMIT_4626_WITHDRAW` unlimited. From spell 20260924 on, such
   writes are listed as commented pseudo-arguments inside the call, aligned with the real ones:
   ```solidity
       depositSlope : 5_000_000e18 / uint256(1 days) // BEFORE: 0
   //  withdrawDepositAssetMax      : unlimited         BEFORE: 0
   //  withdrawDepositAssetSlope    : 0                 BEFORE: 0
   ```
   A helper call without these lines is a finding.
5. **Naming.** The Grove allocation unit is `PAU`/`pau` in identifiers, comments, and prose, never
   `DPAU`/`dpau`, even where an upstream spec says "Diamond PAU".
6. **Reuse shared constants.** Rate-limit keys that `GrovePauHelpers` or
   `GroveLiquidityLayerHelpers` already define are referenced from there, not re-derived with a
   local `keccak256("...")`. Local key constants are only for names the helpers lack.
7. **Numeric values are inlined at the call site**, never extracted into contract constants.
   Address and `bytes32` constants are fine.
8. **Prefer existing helpers** from `GrovePayloadEthereum` / `GrovePayload<Chain>` or an upstream
   `deploy/` library over raw interface calls; raw calls are acceptable only when no helper covers
   the action and the reason is stated in a comment.
9. **Previous-spell dependency.** If the new spell reads or edits state that the most recent
   archived spell creates, the test's `setUp()` must execute that spell (via an
   `_executePreviousSpell()` helper with an obsolescence guard) between `setupDomains(...)` and
   `deployPayloads()`. Point it out when the dependency is visible and the helper is absent.
10. **Dependency pins.** Any change to a `lib/` submodule needs a matching `foundry.lock` entry in
    the same commit, pinned to a specific commit, and a row in the body's "Dependencies Updated"
    table when the spell itself introduces the dependency.

## What not to flag

- `PAYLOAD_<CHAIN> = address(0); // TODO: set after foreign payload deploy` in a spell PR that has not
  reached the deployment stage. Foreign payloads are deployed after review; the constructor is wired
  in a later commit. The harness simulates the local foreign payload while the constant is zero, so
  tests are meaningful.
- `Address TBD` / `Codehash TBD` / `(TBD)` links under "Spell Deployment" in the body before the
  payload is deployed. These are filled by the deployment step.
- The `setupDomains("<ISO timestamp>")` argument. It is a fork point in the recent past, not a
  schedule. Its distance from the execution date is never a finding, and it must not be moved
  toward the execution date.
- In archive PRs: "Dependencies Updated: _None_" alongside `foundry.lock` bumps of the two address
  registries. That table lists dependencies the spell introduced; registry refreshes happen every
  archive cycle. Likewise the `git mv` of the spell files and the literal-to-constant swaps.
- An empty archive PR body. Archive PRs carry no description by convention; the diff is the
  description. Do not ask for one.
- The `## Forum Post` link text being the forum thread title in square brackets, e.g.
  `[[September 24, 2026] - Proposed Changes ...](https://forum...)`. That is the intended format.
- `foundry.toml` setting both `src` and `test` to `"src"`; tests live beside payloads on purpose.
- Anything under `archive/`, and the intentional hardcoded constants in
  `src/test-harness/CommonTestBase.sol`.
- Style-only remarks (import ordering, NatSpec wording, blank lines) unless they hide a
  correctness problem.

## How to write findings

- One comment per distinct issue, anchored to the exact line, stating what is wrong and what the
  expected value or pattern is. Cite the helper or archived spell you are comparing against.
- When the PR body and the code disagree, ask which is right rather than assuming the code is.
- Prefer a concrete suggestion block when the fix is a one-liner.
- Do not restate the PR overview or summarise files; the reviewers already know what the spell does.
- Never justify a verdict with the repository's inherent risk. That these are mainnet governance
  spells moving real funds is true of every PR here, so "correctness depends on state I cannot verify"
  tells the reviewers nothing. Report a concrete finding, or say what the PR is waiting on.
