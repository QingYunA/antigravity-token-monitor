<div align="center">

<img src="./assets/logo.svg" width="64" height="64" alt="Antigravity Token Monitor Logo">

# Antigravity Token Monitor

<p><strong>Local real-time token spend and official quota monitor for Google DeepMind Antigravity.</strong><br>
Includes a native macOS menu bar app, responsive Web dashboard, and terminal CLI. Zero external dependencies, zero data leakage.</p>

<p>
  <a href="https://github.com/QingYunA/antigravity-token-monitor/releases"><img src="https://img.shields.io/github/v/release/QingYunA/antigravity-token-monitor?style=flat&color=38bdf8" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20(Universal)%20%7C%20Web-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/dependencies-0%20pip%20%7C%200%20npm-emerald" alt="Zero Dependencies">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</p>

<p>
  <a href="#features">Features</a> ·
  <a href="#quickstart">Quickstart</a> ·
  <a href="#how-it-works">How It Works</a> ·
  <a href="#updates">Updates</a> ·
  <a href="./README.md">简体中文文档</a>
</p>

</div>

---

<!-- Visuals first: Real macOS menu bar card and Web dashboard -->
<div align="center">
  <img src="./assets/menu_bar_card.png" width="360" alt="Antigravity Monitor macOS Menu Bar Card">
  <p><em>macOS menu bar extra: Instant 7-day/daily token burn, cache hit savings, and 5h/weekly quota countdown</em></p>
  <br>
  <img src="./assets/web_dashboard.png" width="860" alt="Antigravity Monitor Web Dashboard">
  <p><em>Responsive Web dashboard: Native SVG 1:1 pixel timeline, model breakdowns, and step-by-step thinking tokens</em></p>
</div>

---

## Why Antigravity Token Monitor?

When coding heavily with Google DeepMind Antigravity, background agents call models frequently, consuming tokens at high velocity.

Developers face three everyday frustrations:
1. **Quota Black Box**: Antigravity offers no persistent desktop widget. You only notice limits when hitting `ResourceExhausted` errors.
2. **Invisible Spend**: Hard to tell how many tokens a complex task consumed, or how much prompt caching actually saved.
3. **Privacy Concerns**: Many cloud monitoring tools require transmitting session logs and code to third-party servers.

**Antigravity Token Monitor** runs entirely locally. It parses local SQLite databases and queries the local Language Server process. No API keys required, zero outbound telemetry, ready out of the box.

---

## Features

- **Native macOS Menu Bar App:** Written in pure Objective-C and AppKit. Tiny 200KB binary, ~15MB RAM footprint, runs without installation.
- **Official Quota Countdown:** Direct local IPC connection to the Language Server. Displays exact 5-hour and weekly quota remaining percentages and reset timers. Flags red below 10%.
- **Undistorted 1:1 Pixel Charts:** Pure vanilla SVG. Seamlessly switch between **Area Trend** and **Histogram** modes. Uses dynamic container pixels to eliminate aspect-ratio warping and text blur, complete with debounced `ResizeObserver`.
- **Thinking Token Breakdown:** Inspects deep reasoning tokens from Gemini 3.8 and Claude models, including their percentage of total output.
- **Step Pulse & Session Details:** Reconstructs token consumption for every interaction step (input, thinking, output, and cache hit) along with estimated costs.
- **Bilingual & Dual Themes:** One-click language switch (`[ 中文 | EN ]`) and light/dark theme toggle across both menu bar and Web UI.
- **Zero Network Intrusion:** Reads exclusively from local `~/.gemini/antigravity` storage. Never uploads code, prompts, or conversation contents.

---

## Quickstart

### Option 1: macOS DMG Installer (Recommended)

1. Download `Antigravity-Monitor-macOS-Universal.dmg` from the [Releases page](https://github.com/QingYunA/antigravity-token-monitor/releases/latest).
2. Open the DMG image and drag `Antigravity Monitor` into your `Applications` folder.
3. Open the app from Launchpad or Spotlight. The monitor icon will pin to your macOS menu bar.

> **Note**: Universal Binary built natively for both Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

### Option 2: Build from Source

```bash
git clone https://github.com/QingYunA/antigravity-token-monitor.git
cd antigravity-token-monitor

# Compile and launch immediately
./macos/build.sh run

# Package into a native macOS DMG installer
./macos/build.sh dmg

# Or install directly to /Applications
./macos/build.sh install
```

---

### Option 3: Launch Web Dashboard

For 30-day analytics, time-series curves, or step-by-step thinking tokens:

```bash
python3 server.py
```

Open [http://127.0.0.1:8765](http://127.0.0.1:8765) in your browser.

- Instant light and dark mode toggling.
- `[ 中文 | EN ]` language switch with live currency conversion.
- Area trend and histogram toggle with hairline cursor and clean tooltips.

---

### Option 4: Terminal CLI

Quick terminal check while coding:

```bash
python3 cli.py
```

Example output:
```text
============================================================
              ANTIGRAVITY TOKEN MONITOR REPORT              
============================================================
📅 Period: 2026-03-08 to 2026-03-14 (Last 7 Days)
------------------------------------------------------------
📊 Token Burn Overview:
   • Total Tokens:     2.28B Tokens (Est. Cost: $70.46)
   • Cache Hit:        2.15B Tokens (Saved: $160.95)
   • Cache Hit Rate:   94.0%
------------------------------------------------------------
⏱️ Official Quota Status:
   • Gemini 5h Limit:  63.1% Remaining (Resets in: 4h 08m)
   • Weekly Limit:     93.9% Remaining (Resets in: 6d 23h)
============================================================
```

---

## How It Works

Runs strictly on local data generated by Antigravity:

| Metric | Source | Mechanism |
| :--- | :--- | :--- |
| **Official Quota & Reset Timers** | Local Connect-RPC | Scans local `antigravity-language-server` ports and CSRF tokens, invoking `RetrieveUserQuotaSummary` via local RPC. |
| **Token Volume & Spend** | Local SQLite Databases | Reads `~/.gemini/antigravity/conversations/*.db`, decoding Protobuf payloads for exact prompt, output, thinking, and cached token billing. |
| **Zero-Dependency Core** | Python 3 Standard Library | Backend requires zero pip packages (built on `http.server`, `sqlite3`, `urllib`, and `threading`). |

---

## Updates

- **Menu Bar Check**: Click `Check for Updates...` in the macOS menu bar extra.
- **Web Dashboard**: An update pill alerts you when a newer version is available.
- **One-Command Upgrade**: Run `./update.sh` to pull changes, recompile, and restart smoothly:
  ```bash
  ./update.sh
  ```

---

## Automated Tests

Run the full automated test suite:

```bash
python3 run_tests.py
# Or using standard unittest discovery
python3 -m unittest discover -s . -p "test_*.py"
```

---

## License

Released under the [MIT License](./LICENSE).
