---
name: code-review
description: Review process for grove-spells pull requests. Load it for any review in this repository; it governs spell PRs, which run a multi-week governance lifecycle and merge only after the spell executes on-chain. Works out which stage a spell PR has reached from its comments and reviews, then states the next step of that process instead of a generic verdict.
---

# Reviewing spell PRs in grove-spells

Applies to **spell PRs** only — the PR shapes are defined in `.github/copilot-instructions.md`, which
also holds every code-level rule. Archive and infra PRs get an ordinary review and an ordinary merge;
stop reading here for those.

A spell PR is not an ordinary feature PR. It stays open for two to four weeks while a fixed governance
process runs — two reviews, deployment, two deployment reviews, an off-GitHub handover, two handover
confirmations, then execution on-chain — and it merges only afterwards. Your job is to establish which
stage it has reached and name the next step, not to judge whether the branch could be merged today.

## Establish the stage before writing anything

The diff cannot tell you the stage. Read the pull request timeline with the GitHub MCP server, which is
available to you by default — `get_pull_request_comments` and `get_pull_request_reviews`, or the
underlying endpoints:

- issue comments — `GET /repos/{owner}/{repo}/issues/{number}/comments`
- reviews, including their bodies and states — `GET /repos/{owner}/{repo}/pulls/{number}/reviews`

Then count sign-offs as defined below. If the timeline is genuinely unavailable, say so in one line and
fall back to the earliest stage the diff supports. Never guess a later stage.

## Counting sign-offs

- Count **distinct human authors**. Ignore bots (`copilot-pull-request-reviewer[bot]`,
  `octane-security-app[bot]`) and your own earlier reviews.
- A sign-off is a standalone assertion: a heading, a bold line, or a short line whose whole content is
  the phrase, with any decoration (`✅`, `:shipit:`, `Status:`, `TL;DR:`, `#`, `**`).
- One author counts once per stage, however many times they repeat themselves.
- Do not count quoted text (lines starting `>`), unticked checklist items, or a phrase inside a
  sentence that defers it.
- Read for intent, not just for the phrase. An `APPROVED` review saying "we consider the spell ready
  for deployment and safe" is a Good to Deploy even though it never uses the words.

### Good to Deploy

Counts:

```text
# ✅ Good to deploy
## Good to Deploy
### Status: Good to deploy
**Good to deploy**
Good to deploy ✅
TL;DR: Good to Deploy :shipit:
**Current status: Good to deploy** — Certora independent review at `2ad97ba`.
```

Does not count:

```text
**Ready for external review**                    internal review done, external not started
Initial internal review, good to start full review
**wip; waiting for Grove Snapshot votes, governance polls and atlas edit merge**
**Awaiting governance**
- [ ] All tests are passing in CI                a checklist item, not a verdict
# Development Stage Review                       a report; look for a verdict inside it
```

### Deployment

The spell crafter posts two comments:

```text
## Spell Deployment       deployed addresses and the mainnet codehash
## Tenderly Simulations   simulation links
```

Code-side confirmation: `PAYLOAD_<CHAIN>` holds a real address rather than `address(0)`, and the PR
body's "Spell Deployment" section carries addresses and a codehash instead of `Address TBD` /
`Codehash TBD`.

If a later comment reports a redeployment ("Payloads were redeployed. These simulations are outdated."),
the newest deployment is the live one. Count only handover sign-offs posted after it.

### Good to Handover

Counts:

```text
**Good to handover**
## Good to Handover
### Status: Good to handover
Good to handover ✅
TL;DR: Good to Handover 🪇
# Deployment Stage Review — Good to handover
```

### Handover Confirmed

This is the one sign-off that usually arrives as a **review** rather than a comment: an `APPROVED`
review whose body contains `Confirmed Handover`, normally under `### Handover Stage`. Sometimes the
review body is empty and the same person posts `#### Confirmed Handover` as an issue comment instead.
Count each author once, whichever form they used. Two distinct human approvers means handover is
confirmed.

Handover itself happens off GitHub, so no comment marks it. The confirmations are the only evidence it
took place.

## The ladder

The rows run from earliest to latest. Take the **most advanced** row whose conditions are met — a later
stage's evidence always wins over an earlier stage's.

| Observed state | Next step |
| --- | --- |
| No Good to Deploy | Ready for the first (internal) review |
| One Good to Deploy | Ready for the second (external) review |
| Two or more Good to Deploy, not yet deployed | Ready for deployment |
| Deployed, no Good to Handover | Deployment ready for its first review |
| One Good to Handover | Deployment ready for its second review |
| Two or more Good to Handover, no Handover Confirmed | Awaiting handover |
| One Handover Confirmed | Awaiting the second handover confirmation |
| Two Handover Confirmed, execution date not reached | Awaiting execution on `<date>` |
| Execution date reached or passed | Good to merge |

## Execution date

The spell executes **four days after the date in the PR title**, not on it. `20261008` / "October 8,
2026 Spell" executes on **2026-10-12**.

To decide whether that date has passed without relying on knowing today's date, use the newest timestamp
in the PR timeline — the latest commit, comment, or review. It is a lower bound on the current date.

Never say the spell has executed unless you can establish that. If you cannot, treat it as not executed.

Spell PRs merged before July 2026 were merged ahead of execution. That is the old convention. Do not
take an archived PR's merge date as evidence about the current one.

## Writing the verdict

The overview heading is one of three fixed labels; you cannot add a fourth. Choose like this:

| Situation | Label |
| --- | --- |
| At least one concrete finding | `🟡 Changes recommended` |
| No findings, spell not yet executed | `🔵 Needs a closer look` |
| No findings, execution date passed | `🟢 Approval recommended` |

That table is strict: `🟢` is reserved for after execution, whatever the sign-off count.

The sentence under the label is yours to write, and it is the whole value of the review. When you choose
`🔵`, that sentence must name the stage and the next step.

Write:

```text
No findings. One Good to Deploy recorded (iamchrissmith); the spell is ready for its second, external review.

No findings. Two Good to Deploy recorded and the payloads are not yet deployed, so the next step is deployment.

No findings. Both handover confirmations are in; the spell awaits execution on 2026-10-12 and must not be merged before then.
```

Do not write:

```text
It is a mainnet governance spell that moves real treasury funds and relaxes rate limits, and its
correctness depends on external registry addresses and fork-test execution I cannot fully verify here.

This warrants a closer look before merging.
```

The first is banned because it is true of every pull request in this repository, so it tells the
reviewers nothing they do not already know. The second is banned because merging is never the open
question — the ladder is.

## Commits after a sign-off

Sign-offs attach to a commit, not to the PR. Never recommend repeating a stage that is already signed
off — unless the head commit is newer than that sign-off, which is a real finding: name the sign-offs
that no longer cover the head and the stage to repeat.

One exception: `foundry.toml` sets `bytecode_hash = "none"`, so a comment-only change to a payload
produces identical deployed bytecode. Such a commit does not invalidate a deployment or its codehash.
Any change to code, values, or the constructor does.

## Stage gates the code-level rules

The checks in `.github/copilot-instructions.md` do not all apply at every stage.

- Before the first Good to Deploy, all of them are in scope.
- The unfilled placeholders it tells you not to flag — `PAYLOAD_<CHAIN> = address(0)`, `Address TBD`,
  `Codehash TBD` — become findings once two Good to Deploy sign-offs are in, because deployment is then
  the outstanding step.
- After two Good to Handover, treat the code as frozen. The only findings worth raising are a new
  commit, or a value that contradicts the deployment comment.
