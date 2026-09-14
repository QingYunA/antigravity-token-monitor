# [Show HN / Open Source] Antigravity Token Monitor: 100% Local Quota & Token Tracker for Google Antigravity (Native macOS Menu Bar + Web + Zero Dependencies)

Hi everyone,

Over the past few weeks, I’ve been heavily using Google DeepMind's Antigravity for day-to-day coding. While the agent capabilities are stellar, one recurring frustration drove me crazy: **the quota is a complete black box**.

You're deep in the zone refactoring code, and suddenly—boom—`ResourceExhausted` 429 error. The official interface gives you a rough percentage, but it doesn't answer the questions you actually care about:
- How many minutes until the 5-hour rolling window actually resets?
- How many tokens did that massive multi-step refactor actually burn?
- How much is prompt caching actually saving you vs. raw pricing?
- How many tokens were spent on the thinking/reasoning chain vs. code output?

Most existing LLM observability tools either demand a heavy Docker + PostgreSQL stack, or require streaming your conversation logs to an external SaaS. When working on private repos or client projects, uploading proprietary prompts and session logs to a third party is an immediate dealbreaker.

So I wrote a lightweight, local-first tool to scratch my own itch: **Antigravity Token Monitor**.

- **GitHub Repository**: [https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
- **Latest Releases (macOS DMG)**: [https://github.com/QingYunA/antigravity-token-monitor/releases/latest](https://github.com/QingYunA/antigravity-token-monitor/releases/latest)

It's completely free, MIT-licensed, and 100% of your data stays on your machine.

---

## 📸 What It Looks Like

### 1. Native macOS Menu Bar Card

I didn't want to open a browser tab just to check whether I'm about to hit rate limits. So I built a lightweight native menu bar extra in Objective-C / AppKit:

![macOS Menu Bar Extra Preview](https://raw.githubusercontent.com/QingYunA/antigravity-token-monitor/main/assets/menu_bar_card.png)

- **Tiny footprint**: ~200KB binary, consumes ~15MB RAM. Barely noticeable in the background.
- **Quota countdown**: Live countdown to the minute for both the 5-hour rolling quota and weekly allowance. Automatically turns red when remaining quota drops below 10%.
- **Burn & savings summary**: Shows today's spend, 7-day cumulative token burn, dollar-equivalent cost, and prompt cache hit ratio.
- **One-click access**: Direct access to open the full Web dashboard or check for updates.

---

### 2. Standalone Web Dashboard

When you want to inspect 30-day usage trends or diagnose token spikes from specific complex tasks:

![Web Dashboard Preview](https://raw.githubusercontent.com/QingYunA/antigravity-token-monitor/main/assets/web_dashboard.png)

- **Zero dependencies**: Pure vanilla HTML, CSS, and SVG. Zero npm packages, zero external CDNs. Works completely offline.
- **Dynamic 1:1 SVG pixel charts**: Crisp area/bar charts rendered strictly to physical container dimensions (no stretched ellipses or blurry fonts). Includes interactive crosshairs and peak/average annotations.
- **Thinking token inspection**: Breaks down reasoning tokens vs. output tokens for Gemini and Claude models.
- **Step-by-step session telemetry**: Inspect individual agent interactions—prompt tokens, cache hits, completion tokens, and estimated cost.
- **Finishing touches**: Dark/light mode toggle, USD/CNY currency switcher, and English/Chinese UI translations.

---

### 3. Terminal CLI

For keyboard-first workflows or tmux users:

```bash
python3 cli.py
```

Prints a clean text report in under 100ms:

```text
============================================================
              ANTIGRAVITY TOKEN MONITOR REPORT              
============================================================
📅 Period: 2026-03-08 to 2026-03-14 (Last 7 Days)
------------------------------------------------------------
📊 Core Token Usage:
   • Total Consumed:  2.28B Tokens (Est. Value: $70.46)
   • Cache Hits:      2.15B Tokens (Cache Saved: $160.95)
   • Cache Ratio:     94.0%
------------------------------------------------------------
⏱️ Official Quota Status:
   • Gemini 5h Limit: 63.1% remaining (Reset in: 4h 08m)
   • Weekly Limit:    93.9% remaining (Reset in: 6d 23h)
============================================================
```

---

## 🔒 Privacy & Architecture (Why You Can Trust It)

- **Zero Network Egress**: The tool reads local SQLite databases at `~/.gemini/antigravity/` and communicates with the local `antigravity-language-server` process via loopback RPC (`127.0.0.1`). It never transmits your code, prompts, tokens, or session history to the internet.
- **Zero PIP Dependencies**: The backend uses Python 3's built-in standard library (`http.server`, `sqlite3`, `urllib`). No `pip install` required, eliminating dependency bloat and supply chain risks.
- **Native Connect-RPC Client**: Fetches quota figures directly by discovering the active language server port and local CSRF token—mirroring how the official IDE retrieves its data.

---

## 🚀 Getting Started

### Option A: macOS DMG (Easiest)

1. Download `Antigravity-Monitor-macOS-Universal.dmg` from [GitHub Releases](https://github.com/QingYunA/antigravity-token-monitor/releases/latest).
2. Open the DMG and drag **Antigravity Monitor** into your `/Applications` folder.
3. Launch it. The icon will sit in your menu bar.
   *(Universal binary natively compiled for Apple Silicon M1–M4 & Intel Macs)*

### Option B: Run from Source (Any OS)

```bash
# Clone the repository
git clone https://github.com/QingYunA/antigravity-token-monitor.git
cd antigravity-token-monitor

# Run the Web dashboard using Python standard library
python3 server.py

# Open your browser at http://127.0.0.1:8765
```

If you're on macOS and want to compile the menu bar app yourself:
```bash
./macos/build.sh run
```

---

## 💬 Feedback & Contributions

I built this primarily to stop flying blind during my own coding sessions. Having the countdown and cache savings visible in the menu bar has made using Antigravity far more predictable.

If you're using Antigravity and have feedback, feature requests (e.g., custom notification thresholds, multi-account support), or run into edge cases, feel free to drop a comment, open a GitHub Issue, or submit a PR!

If you find it useful, a star on GitHub is always appreciated:

⭐ **GitHub**: [https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
