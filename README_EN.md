<div align="center">

<img src="./assets/logo.svg" width="68" height="68" alt="Antigravity Token Monitor Logo">

# Antigravity Token Monitor

<p><strong>Local real-time token usage and official quota monitor for Google DeepMind Antigravity.</strong><br>
Includes a native macOS menu bar card, lightweight Web dashboard, and terminal CLI. Zero external dependencies, zero network intrusion.</p>

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

<div align="center">
  <img src="./assets/menu_bar_card.png" width="380" alt="Antigravity Monitor macOS Menu Bar Card">
  <p><em>Native macOS menu bar extra: Live 7-day & today token consumption, cache hit rate, and official 5-hour/weekly quota countdown.</em></p>
</div>

---

## Why Antigravity Token Monitor?

When pair-programming heavily with Google DeepMind Antigravity, coding agents frequently call Gemini models under the hood, consuming significant volumes of tokens.

In daily workflow:
1. **Quota Black Box**: You only realize limits are reached when hit by `ResourceExhausted` errors.
2. **Invisible Spend**: Hard to see how many tokens a complex subagent task burned, or how much prompt caching saved you.
3. **Privacy Concerns**: Monitoring shouldn't require shipping your session logs or code to third-party cloud services.

**Antigravity Token Monitor** operates entirely locally. It parses local SQLite files and queries the local Language Server process. No API keys needed, zero outbound network telemetry.

---

## Features

- **Native macOS Menu Bar App:** Built with pure Objective-C & AppKit. Tiny 200KB binary, consumes ~15MB RAM, runs out-of-the-box.
- **Usage-First Layout:** Status card prioritizes 7-day and daily token volume along with cache hit savings, complemented by official pricing estimates.
- **Official Quota Countdown:** Direct local IPC connection to the Language Server for exact 5-hour and weekly quota percentages and reset timers. Auto-flags red and triggers macOS notifications below 10%.
- **Bilingual i18n Support:** Hot-swap between English and Chinese in both the menu bar app and the Web UI. Preferences persist in system defaults and `localStorage`.
- **Responsive Web Dashboard:** Pure vanilla HTML/CSS/JS in a single file with zero npm dependencies. Supports light/dark mode and aggregation over Today, 7D, 30D, and All-Time.
- **Step-by-Step Pulse Inspector:** Inspect individual interaction steps with prompt, thinking, output, and cache token breakdowns.
- **Zero Network Intrusion:** Reads strictly from `~/.gemini/antigravity` locally. Never transmits code, prompts, or conversation contents externally.

---

## Quickstart

### Option A: Prebuilt macOS App (Recommended)

1. Download `Antigravity-Monitor-macOS-Universal.zip` from [Releases](https://github.com/QingYunA/antigravity-token-monitor/releases/latest).
2. Unzip and drag `Antigravity Monitor.app` into `/Applications` (or any directory).
3. Open the app to see the Antigravity Quantum Core icon in your macOS menu bar.

> **Note**: Packaged as a Universal Binary, running natively on both Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

### Option B: Build from Source

Clone and build with one command:

```bash
git clone https://github.com/QingYunA/antigravity-token-monitor.git
cd antigravity-token-monitor

# Compile and launch immediately
./macos/build.sh run

# Or install directly to /Applications
./macos/build.sh install
```

---

### Option C: Launch Web Dashboard

For interactive charts, 30-day trends, and full session breakdowns:

```bash
python3 server.py
```

Open [http://127.0.0.1:8765](http://127.0.0.1:8765) in your browser.

- Instant light/dark theme toggle.
- `[ 中文 | EN ]` toggle in top navigation.
- Today, 7-Day, 30-Day, and All-Time filters.

---

### Option D: Terminal CLI

Quick terminal check while coding:

```bash
python3 cli.py
```

---

## How It Works

| Data | Source | Details |
| :--- | :--- | :--- |
| **Official Quota & Reset Timers** | Local Connect-RPC | Discovers local `antigravity-language-server` process and CSRF tokens, invoking `RetrieveUserQuotaSummary` for real-time quota data. |
| **Token Usage & Pricing** | Local SQLite Parsing | Reads `~/.gemini/antigravity/conversations/*.db`, decoding `gen_metadata` Protobuf payloads for exact prompt, output, thinking, and cached tokens. |
| **Zero Dependencies** | Python 3 Standard Library | Backend uses built-in `http.server`, `sqlite3`, `urllib`, and `threading`. |

---

## Updates

- **Menu Bar Check**: Click `Check for Updates...` in the macOS menu bar extra.
- **Web Dashboard**: An update pill alerts you when a newer version is available.
- **One-Command Upgrade**: Run `./update.sh` to pull changes, recompile, and restart smoothly:
  ```bash
  ./update.sh
  ```

---

## Tests

Run the full automated test suite:

```bash
python3 -m unittest discover -p "test_*.py"
```

---

## License

Released under the [MIT License](./LICENSE).
