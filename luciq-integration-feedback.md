# Luciq iOS integration — friction report

**App:** Split Me (SwiftUI, iOS 17 target, SPM, no prior third-party SDKs)
**SDK:** luciq-ios-sdk 19.10.1 · **Date:** 7 September 2026
**Integrated by:** an AI coding agent following `luciq-skills` + the AI Agent
Integration Guide, which is the path this feedback is about.

The integration succeeded and the SDK works: crash reporting, bug reports and
APM are live, a test crash was captured and uploaded. But it took far longer
than "one shot", and most of the delay traces to a handful of specific things.
Ordered by how much time each cost.

---

## 1. The agent guide contains pseudo-code mixed with real API calls

**Cost: a failed build and a docs round-trip.**

The iOS network-masking sample in the AI agent guide is not valid Swift:

```swift
let headersToMask: [String] = IF config_mode == default:
    ["Authorization", "Cookie", "X-API-Key", "token"]
ELSE:
    ["Authorization", "Cookie", "X-API-Key"]
```

`IF … ELSE:` is prose in the middle of a code block. An agent reading a guide
addressed *to agents* reasonably treats the surrounding code as authoritative,
fills in the branch, and ships the rest verbatim — including the API name. That
produced a call to `NetworkLogger.setNetworkDataObfuscationHandler`, which does
not exist; the real name is `setRequestObfuscationHandler`, and it appears
correctly further down the same page.

**Suggestion:** keep configuration logic in prose and code blocks in compilable
Swift. If the sample must branch, show two complete snippets.

## 2. Nothing in the guide explains how to verify crash reporting

**Cost: the longest single detour — a crash that looked like it had failed.**

We triggered a deliberate crash to check the pipeline. Two undocumented
behaviours made it look broken:

- **With the Xcode debugger attached, a Swift trap pauses the process.** It
  presents as a *freeze*, not a crash, and no report is produced. The customer's
  words were "it freezed but not crashed".
- **Reports upload on the next launch,** not at crash time. So even after a real
  crash, the dashboard stays empty until the app is reopened — which looks like
  a broken integration.

Neither is mentioned in the setup guide or the `luciq-setup` skill.

**Suggestion:** add a short "Verify crash reporting" section: crash outside the
debugger, relaunch, then check. It would have saved most of this.

## 3. No way to tell whether the SDK is running

**Cost: repeated guessing while diagnosing.**

There is no documented health signal — no `Luciq.isRunning`, no start-up log at
default verbosity. We ended up confirming initialisation by listing the app
container and finding `Library/IBGCache/` and `InstabugDataModel*`. That works,
but it is not something a customer should have to discover.

**Suggestion:** a documented debug log line on successful start, or a queryable
state flag.

## 4. `list_applications` (MCP) is unusable on a large account

**Cost: the token had to be requested from the customer anyway, twice.**

The skill and the guide both say: fetch tokens via MCP, show them in a numbered
list, ask which to use. On this account `list_applications` returns 100+
applications — demo apps, test apps, other people's apps — with:

- no name search or filter,
- no way to look up an application **by token** (given a token, we could not
  confirm which app it belonged to),
- paging via `limit`/`offset` only.

Presenting a hundred tokens for selection is worse than asking. And when the
customer supplied a token, we could not verify it pointed at the intended app.

**Suggestion:** `search_applications(query:)`, and `get_application(token:)`.
The second matters for exactly this case — confirming a token before shipping
with it.

## 5. Hand-editing `project.pbxproj` is prescribed as the agent path

**Cost: a build failure with a misleading error.**

The guide instructs agents to add SPM support by making six separate edits to
`project.pbxproj` with hand-generated 24-hex IDs. It works, but it is fragile,
and it produced this:

```
error: Missing package product 'Luciq'
```

The cause was **Xcode being open while the project file was edited**. Xcode
picked up the new package reference but never resolved it, leaving
`workspace-state.json` with `Luciq → None`. Compounding it,
`xcodebuild -resolvePackageDependencies` resolves into a *different*
DerivedData than the open Xcode session, so the command the guide recommends
appears to succeed while Xcode still fails.

**Suggestions:**
- Warn that the project must be closed in Xcode, or reopened afterwards.
- State that resolution is per-DerivedData, and that Xcode needs
  *File → Packages → Resolve* (or a restart).
- Better: ship a CLI (`luciq init ios`) that performs the SPM wiring. Every
  agent doing this by hand will make different mistakes.

## 6. The privacy consequences of enabling features are undocumented

**Cost: the most serious issue found, though it cost little time — because we
went looking. Someone who does not look ships a misdeclared app.**

The SDK's own `PrivacyInfo.xcprivacy` declares **nine** data types:

| Declared by the SDK | Linked to identity |
| --- | --- |
| Crash Data, Performance Data, Other Diagnostic Data | No |
| Product Interaction | No |
| Photos or Videos | No |
| Audio Data | No |
| **Name, Email Address, User ID** | **Yes** |

Nothing in the setup guide connects SDK configuration to what the customer must
then declare on their App Store privacy card. Two concrete traps:

- `setReproStepsFor(.all, with: .enable)` — recommended in the Session Replay
  docs for screenshots — silently means the app now collects **Photos or
  Videos**. For an app whose screens show names and amounts, that is a material
  disclosure change.
- If the bug-report form asks reporters for an email, the app collects **Email
  Address, linked to identity** — which contradicts "we have no accounts" and
  changes the privacy card substantially. There is no prominent pointer to the
  setting that turns it off.

Apple rejects mismatches between the privacy card and the binary. This is the
one gap most likely to cause a customer a rejection.

**Suggestion:** a doc page mapping *features enabled* → *App Privacy categories
to declare*, plus the switches that reduce the surface
(`emailFieldRequired`, voice notes, auto-masking, private views).

## 7. dSYM upload is marked MANDATORY but cannot be automated from the docs

The guide lists symbolication as a mandatory step, then says to download
`Luciq_dsym_upload.sh` **from the dashboard** — with no URL, and no
scriptable alternative in the same page. An agent cannot complete a step that
requires a human to fetch a file from a web UI, so the step gets deferred, and
the first crashes arrive unsymbolicated. That is a poor first impression of a
crash reporter.

**Suggestion:** a stable download URL or, better, a documented
`luciq-cli upload-dsym` invocation alongside the build-phase snippet.

## 8. Smaller things

- **`luciq-skills install` is excellent** — it installed 11 skills and wired the
  MCP server into `.claude/settings.json` unprompted. Best part of the
  experience. One gap: newly installed skills are not available to an
  already-running agent, so the installer should say "restart your agent".
  The skill's own step 7 says this about MCP; the installer does not.
- **The `Luciq` vs `import LuciqSDK` warning works.** It is stated three times,
  emphatically, and it prevented the error it describes. More docs should be
  written like this.
- **Docs copy/paste bug:** in *Setup Session Replay → Enabling/Disabling*, the
  Objective-C tab shows `LCQSessionReplay.networkLogsEnabled` for the
  enable/disable toggle, where the Swift tab correctly shows
  `SessionReplay.enabled`.
- **Rebrand leakage.** On-device artefacts are still `Instabug`-named
  (`InstabugDataModel`, `IBGCache`, `com.plausiblelabs.crashreporter.data`), and
  the API surface mixes `IBG` into new names (`SessionReplay.IBGLogsEnabled`).
  Harmless, but it makes verification confusing — you cannot grep for "luciq"
  and find your own SDK's files.
- **The agent guide is one 56 KB page covering five platforms.** MCP
  `search_documentation` returned 88 KB for a single query, which exceeded the
  tool's response limit and had to be spilled to a file and parsed. Per-platform
  pages, or a summarised MCP response, would help.
- **`INFOPLIST_KEY_<CustomKey>` does not work.** Guidance to inject the token at
  build time has no concrete iOS recipe, and the obvious approach silently
  fails: Xcode only injects Info.plist keys it recognises, so a custom key is
  dropped with no error. The working recipe — a gitignored `.xcconfig`, a
  `$(VAR)` reference in a real `Info.plist`, read via `Bundle.main` — is worth
  documenting outright.

---

## What was mine, not yours

For fairness, several delays were the agent's fault and no fix on your side
would have prevented them:

- Guessing the masking API instead of reading to the end of the page first —
  though see item 1 for why the page invited it.
- Choosing invocation events (`shake` + `screenshot`) with **no visible entry
  point**, which made a working SDK look dead. The guide's default of
  shake + floatingButton was right; deviating from it was not. A note that at
  least one visible invocation is advisable would still be a cheap safeguard.
- Testing with the debugger attached before reading how crash capture behaves.

## Net

Roughly **75% of the elapsed time** went on items 1, 2 and 5 — a docs code
sample that does not compile, no guidance on verifying a crash, and hand-editing
the Xcode project. All three are fixable with documentation and one small CLI.
Item 6 is not a time cost but is the most consequential: it is the one that
could put a customer in front of App Review with a privacy card that does not
match their binary.
