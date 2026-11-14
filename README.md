<div align="center">
  <img src=".github/assets/social-banner.png" alt="Parrot Reforged Banner" width="100%" />

  # Parrot Reforged

  **The Iconic Floating Combat Text Addon — Completely Reforged for Retail 12.x (Midnight), Classic Forever & All Classic Flavors!**

  [![Code Quality](https://github.com/gOOvER/Parrot-Reforged/actions/workflows/quality.yml/badge.svg)](https://github.com/gOOvER/Parrot-Reforged/actions/workflows/quality.yml)
  [![Release](https://github.com/gOOvER/Parrot-Reforged/actions/workflows/release.yml/badge.svg)](https://github.com/gOOvER/Parrot-Reforged/actions/workflows/release.yml)
  [![GitHub Release](https://img.shields.io/github/v/release/gOOvER/Parrot-Reforged?include_prereleases&label=Version&color=brightgreen&logo=github)](https://github.com/gOOvER/Parrot-Reforged/releases/latest)
  [![CurseForge](https://img.shields.io/badge/CurseForge-Parrot%20Reforged-f16436?logo=curseforge&logoColor=white)](https://www.curseforge.com/wow/addons/parrot-reforged)
  [![Wago.io](https://img.shields.io/badge/Wago.io-Parrot%20Reforged-c1272d?logo=wagtail&logoColor=white)](https://addons.wago.io/addons/parrot-reforged)
  [![WoW Versions](https://img.shields.io/badge/WoW-Retail%20%7C%20MoP%20%7C%20Cata%20%7C%20Wrath%20%7C%20TBC%20%7C%20Classic%20%7C%20Forever-f8b700?logo=battle.net&logoColor=white)](#-supported-wow-versions)
  [![License: LGPL v2.1](https://img.shields.io/badge/License-LGPLv2.1-blue.svg)](LICENSE)
  [![Support](https://img.shields.io/badge/Support-donate.goover.dev-ff69b4?logo=ko-fi&logoColor=white)](https://donate.goover.dev)
</div>

---

**Parrot Reforged** brings the legendary **Parrot** Floating Combat Text (FCT) addon into the modern era of World of Warcraft — featuring a **Modern Dark-Gold UI**, sub-pixel 120–240Hz animations, taint-free nameplate anchoring, automatic class proc detection, profile/trigger `!PAR1!` sharing, full **Retail 12.0+ (Midnight) `<secret number>` / `<secret string>` protection**, and seamless **ElvUI** & **AddOnSkins** integration.

---

## 🎮 Supported WoW Versions

- **Retail (Midnight `12.x` & The War Within `11.2.x`)**
- **Mists of Pandaria Classic (`5.5.x`)**
- **Cataclysm Classic (`4.4.x`)**
- **Wrath of the Lich King Classic (`3.4.x` & Titan Reforged `3.8.x`)**
- **The Burning Crusade Classic Anniversary (`2.5.x`)**
- **Classic Era (`1.15.x`) & Classic Forever (`1.60.x` / `16001`)**

---

## ✨ Key Features

- 🏛️ **Modern Dark-Gold Configuration Suite & Precision Movers**:
  - **Standalone Resizable Dark-Gold Window (`ParrotConfigFrame`)**: Vertical category sidebar, full-height scrollable sections with wide non-truncating 2-column layouts, live `A-` / `13pt` / `A+` UI font scaling, bottom-right resize grip + `LibWindow-1.1` position memory, and footer quick-action buttons (**Demo Burst**, **Unlock/Lock Anchors**, **Modern Preset**, **Enable/Disable**).
  - **Precision Scroll Area Anchors**: `DIALOG`-strata dark-gold movers with center crosshair alignment guides (`+`), **1px / 10px nudge buttons (`◄ ▲ ▼ ►`)**, Right-Click to lock, and realistic multi-school preview bursts.
  - **Interactive `LibQTip-1.0` Minimap Tooltip**: Live status, active profile, CombatLog/Fallback engine indicator, clickable quick actions, and mouse button shortcuts.
- ✨ **Modern Sub-Pixel Animation Engine & Nameplate Anchoring**:
  - **120–240Hz Sub-Pixel Rendering** (`Code/AnimationEasing.lua` & `Code/Display.lua`): Disables integer pixel-grid snapping (`SetSnapToPixelGrid(false)`) with mathematical easing curves, smooth sine/cosine fade envelopes, hardware `SetScale` crit punch-pop, and damped anti-overlap gliding.
  - **15 Animation Styles**: Includes 5 modern styles (**Fountain**, **Impact**, **Cascade**, **Pop-Up**, **Splash**) alongside modernized classics (*Parabola, Straight, Semicircle, Rainbow, Sprinkler, Pow, Angled, Horizontal, Static, Action*) plus a one-click **Modern Preset**.
  - **Taint-Free Nameplate Anchoring**: Optionally attach outgoing/incoming numbers directly to **enemy or target Nameplates** (with X/Y offsets and automatic screen-position fallback) without tainting Blizzard, Plater, or ElvUI nameplates.
- 💥 **Enhanced Combat Feedback, Smart Raid Anti-Spam & Rich Loot**:
  - **Styled Icon Borders & `LibCustomGlow-1.0` Effects**: Crisp framed spell icons with spell-school-colored rims and animated **Pixel**, **Sparkle**, **Spell Alert**, or **Proc** glows on critical strikes, triggers, **Killing Blows**, **Epic+ Loot**, and **Renown Rank-Ups**.
  - **Smart Raid & AoE Anti-Spam**: Dynamic AoE throttle window widening during dense multi-target pulls (`>12 hits/sec`) plus gear-scaling **`% Max HP` minimum damage/healing thresholds** (`0%–5%`).
  - **Rich Loot, Coin Icons, Honor & Renown**: Inline gold/silver/copper coin icons, minimum item quality filter, PvP **Honor Gains**, and Retail **Major Faction Renown** celebration banners.
- 🛡️ **Full Retail 12.0+ (Midnight) & Forever Secret-Value Compatibility**:
  - Two-pass **Secret-Safe Tag Substitution Engine (`replaceTags`)** in `Code/CombatEvents.lua` that resolves normal tags first and concatenates `<secret number>` / `<secret string>` values via `..` without triggering `invalid replacement value (a secret)` errors.
  - **Expanded Combat-Log-Free Fallback Feed (`Code/CombatFeedFallback.lua`)**: Keeps damage, heals, pet combat, dodges/parries/absorbs/misses, dynamic DoT/HoT attribution, spell-school colors, and player aura gains/stacks/fades (`UNIT_AURA`) working even when `COMBAT_LOG_EVENT_UNFILTERED` is restricted.
- 🎯 **Automatic Class Procs, Triggers & `!PAR1!` Profile Sharing**:
  - **Zero-Setup Automatic Class Procs (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`)**: Automatically displays any glowing class ability proc across Classic SoD, Cata, MoP, and Retail Midnight with spell icon, glow, cooldown, and spell ignore filter.
  - **Import / Export (`!PAR1!`)**: Share full profiles (`!PAR1!P!...`) or standalone custom triggers (`!PAR1!T!...`) via `AceSerializer-3.0` + `LibDeflate`.
- 🎨 **First-Class ElvUI, WindTools & BenikUI Integration**:
  - **Pixel-Perfect `SetTemplate("Transparent")` UI**: `ParrotConfigFrame`, scroll area movers, and `1px/10px` nudge buttons automatically adopt ElvUI's `E.mult` 1-device-pixel borders, `E.media.normFont`, `E.TexCoords` icon cropping, `ElvUI_WindTools` soft shadows & `LibQTip` skinning, and `ElvUI_BenikUI` window styling without double-skinning Ace3 widgets.
  - **ElvUI NamePlate & Font Sync**: Anchors nameplate combat text directly to ElvUI's visible `plate.unitFrame.Health` bar (`0` taint), renders pixel-perfect `E.mult` spell icon borders, and provides a dedicated **Use ElvUI font** toggle in Master Font Settings.

---

## ⌨️ Slash Commands

| Command | Description |
| :--- | :--- |
| `/parrot` | Open or toggle the Parrot Reforged configuration window |
| `/parrot anchors` | Unlock or lock scroll area movers with crosshair guides & 1px nudge buttons |
| `/parrot test` | Fire a realistic multi-school combat demo burst across all scroll areas |
| `/parrot share` | Open the `!PAR1!` Profile & Trigger Import / Export tab |
| `/parrot toggle` | Enable or disable Parrot Reforged |
| `/parrot errors` | Display any captured internal error logs |

---

## 📜 Credits & License

- **Original Authors**: ckknight, profalbert, nebula
- **Reforged Modernization**: **gOOvER** ([goover.dev](https://www.goover.dev))
- **License**: [GNU Lesser General Public License v2.1 (LGPL-2.1)](LICENSE)
- **Support Development**: [donate.goover.dev](https://donate.goover.dev) • [Ko-fi](https://ko-fi.com/oldnoob) • [Buy Me a Coffee](https://www.buymeacoffee.com/goover)
