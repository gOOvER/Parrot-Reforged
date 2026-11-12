# Changelog

All notable changes to **Parrot Reforged** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Unreleased

### Added
- **Parrot Reforged Rebranding**: Renamed from `Parrot 2` / `Parrot 3` to **Parrot Reforged** with unified multi-flavor `Parrot.toc` supporting Retail (`12.0+`), MoP Classic (`5.5`), Cata Classic (`4.4`), Wrath Classic (`3.4`), TBC Anniversary (`2.5`), Classic Forever (`1.15` / `1.6`), and Classic Era (`1.15`).
- **Cross-Expansion Compatibility Layer (`Code/Polyfills.lua`)**:
  - Unified `C_Spell.*` / `GetSpellInfo` / `GetSpellTexture` / `GetSpellCooldown` / `IsUsableSpell` APIs.
  - Unified `C_SpellBook.*` / `GetNumSpellTabs` / `GetSpellTabInfo` / `GetSpellBookItemName` / `GetSpellBookItemCooldown` APIs.
  - Unified `C_Item.*` / `GetItemInfo` / `GetItemIconByID` / `GetItemCount` / `GetInventoryItemLink` / `GetInventoryItemCooldown` and `C_CurrencyInfo.GetCurrencyInfoFromLink` APIs.
  - Unified `C_UnitAuras.GetAuraDataByIndex` / `UnitAura` lookup in `Compat.FindAura`.
  - Unified Specialization & Classic Talent Tree detection (`Compat.GetCurrentSpecID` & `Compat.GetSpecInfoByID`) mapping Classic/TBC/Wrath/Cata talent tabs (`1..3`) to class specialization IDs.
  - Built-in `DDI-Font` and `DDI-Sound` AceGUI dropdown item widgets (with live font and sound previews) so `LibDDI-1.0` is no longer required as an external dependency.
- **Combat-Log-Free Fallback Feed (`Code/CombatFeedFallback.lua`)**: Integrated and enhanced the fallback combat feed (`UNIT_COMBAT`, `UNIT_SPELLCAST_SUCCEEDED`, and `C_DamageMeter` polling) with full Retail 12.0+ / Forever secret-value support so floating combat text still works even when `COMBAT_LOG_EVENT_UNFILTERED` is blocked by session taint.
- **ElvUI, WindTools & BenikUI Compatibility (`Parrot.toc`, `Code/UIStyle.lua`, `Code/ConfigWindow.lua`, `Code/Parrot.lua`, `Code/Display.lua`, `Code/ScrollAreas.lua`, `Code/Polyfills.lua`)**:
  - Added `ElvUI` and `AddOnSkins` to `OptionalDeps` in `Parrot.toc`.
  - Native ElvUI window skinning in `Code/UIStyle.lua` & `Code/ConfigWindow.lua`: `ParrotConfigFrame` adopts `SetTemplate("Transparent")`, pixel-perfect `E.mult` 1-device-pixel borders (`insets = 0`), `E.media.bordercolor` panel dividers, `E.media.normFont` UI font inheritance, `E.TexCoords` icon cropping, `ElvUI_WindTools` soft outer shadow (`CreateShadow`), and `ElvUI_BenikUI` header ornament (`BUIStyle`) without double-skinning Ace3 containers inside `ParrotConfigHost`.
  - Native `LibQTip-1.0` Tooltip & Minimap Button Bar compatibility (`Code/Parrot.lua`, `Code/UIStyle.lua`): fixed `LibDBIcon-1.0` & `ElvUI_WindTools` `MinimapButtons` skipping `OnEnter` when `OnTooltipShow` was also defined on the LDB object, and styled `LibQTip` via `ElvUI` (`TT:SetStyle`) / `ElvUI_WindTools` (`LibQTip` skin) without overwriting their `Transparent` backdrop.
  - Visual ElvUI NamePlate HealthBar anchoring (`Code/Display.lua`): `resolveVisualPlateRegion` reads coordinates from ElvUI's visible oUF healthbar (`plate.unitFrame.Health` -> `plate.unitFrame` -> `plate.UnitFrame.healthBar` -> `plate`) via taint-free `pcall` + `IsForbidden` guards.
  - Added **Use ElvUI font** (`useElvUIFont`) option in `Master font settings` (auto-shown when ElvUI is loaded) to sync floating combat text with `E.db.general.font` / `E.media.combatFont`, plus pixel-perfect `E.mult` floating spell icon borders (`2 * mult` outer, `1 * mult` colored rim) and `E.TexCoords` icon cropping.
  - Styled scroll area configuration movers (`ParrotScrollAreasOffsetBox`) and `1px / 10px` nudge buttons with ElvUI's `Transparent` template and pixel-perfect `E.mult` borders & crosshairs.
  - Fixed `DDI-Font` dropdown item recycling in `Code/Polyfills.lua` so `"Inherit"` entries always reset to the default font instead of retaining a recycled item's font face.
- **Warrior Stance Trigger Condition (`Parrot2 #93`)**: Added `Warrior Stance` (`Battle Stance`, `Defensive Stance`, `Berserker Stance`) as a secondary trigger condition in `Data/TriggerConditions.lua`.
- **Hide Throttle Text & Only Show Crits Options (`Parrot2 #47`, `#35`)**: Added `Hide throttle text` under `Events -> Throttle events` and `Only show crits` under `Events` options.
- **Minimap Button, Addon Compartment & Slash Subcommands**: Added `LibDBIcon-1.0` minimap button support (configurable in General options), Retail/Classic Addon Compartment handlers (`Parrot_OnAddonCompartmentClick`, `Enter`, `Leave`), and `/parrot test`, `/parrot toggle`, and `/parrot errors` subcommands.
- **Sub-Pixel Animation & Easing Engine (`Code/AnimationEasing.lua`, `Code/Display.lua`, `Data/AnimationStyles.lua`)**:
  - Added mathematical easing curves (`OutQuad`, `OutCubic`, `OutQuart`, `OutSine`, `OutBack`, `OutElastic`, `CritPopScale`, `NormalPopScale`, `SmoothAlpha`) and disabled integer pixel-grid snapping (`SetSnapToPixelGrid(false)` / `SetTexelSnappingBias(0)`) for silky-smooth 120–240Hz scrolling without 1px stair-stepping.
  - Added 5 modern animation styles: **Fountain** (ARPG ballistic arc), **Impact** (punchy sticky crit pop without continuous shake), **Cascade** (eased S-curve wave), **Pop-Up** (OutBack bounce + stationary reading hold), and **Splash** (radial burst).
  - Added smooth sine fade-in, cosine fade-out, damped anti-overlap separation, **Dynamic Hit Scaling** (rolling-average magnitude scaling + configurable DoT/HoT tick scale), and a one-click **Apply Modern Preset** button.
- **Taint-Free Nameplate Anchoring (`Code/Display.lua`, `Code/ScrollAreas.lua`)**:
  - Added per-scroll-area Nameplate target/unit anchoring (`Unit nameplate` / `Target nameplate` with X/Y offsets and automatic fallback to screen coordinates) by tracking nameplate screen centers without parenting frames to secure NamePlates — preserving animations smoothly even after an enemy dies.
- **Styled Spell Icons & `LibCustomGlow-1.0` Integration (`.pkgmeta`, `embeds.xml`, `Code/Display.lua`, `Code/Triggers.lua`)**:
  - Embedded `LibCustomGlow-1.0` (`https://github.com/Stanzilla/LibCustomGlow`) for animated icon glows (**Pixel**, **Sparkle**, **Spell Alert**, and **Proc Glow**) on critical strikes and triggers.
  - Added pooled icon holders with crisp dark outer borders, subtle top gloss, and spell-school-colored inner rims (with golden accents on crits).
- **Modern Damage & Multi-Hit Presentation (`Code/CombatEvents.lua`, `Data/CombatEvents.lua`, `Code/CombatFeedFallback.lua`)**:
  - Added combined number shortening (`k`, `M`, `B` with configurable `shortenThreshold` from `1,000+` to `1,000,000+`) alongside localized thousands separators (`BreakUpLargeNumbers`) for smaller numbers.
  - Added compact **Modern Hit Badges** (`×5`, `×3!`, `×5 (2!)`) for merged multi-hit/AoE/DoT events, vibrant modern spell-school colors, bitmask multi-school color resolution, and school/GUID forwarding in `CombatFeedFallback.lua`.
- **Modern Dark-Gold Configuration Window, Precision Anchor Movers & Interactive Minimap Tooltip (`Code/UIStyle.lua`, `Code/ConfigWindow.lua`, `Code/ScrollAreas.lua`, `Code/Parrot.lua`, `Code/Display.lua`, `Code/CombatEvents.lua`)**:
  - Added standalone **Modern Dark-Gold UI** (`ParrotConfigFrame`, `1020x700` default with persistent drag-resize grip `880x560`–`1440x980`) featuring a vertical category sidebar (`General`, `Scroll areas`, `Events`, `Triggers`, `Cooldowns`, `Suppressions`, `Import / Export`, `Profiles`), live `A-` / `13pt` / `A+` UI font scaling, `LibWindow-1.1` position persistence, and footer quick-action buttons (**Demo Burst**, **Unlock/Lock Anchors**, **Modern Preset**, **Enable/Disable**).
  - Reorganized `General` and `Events` option layouts into full-height scrollable pages (`inline = true` sections in `General` including `Master font settings`, dedicated `General` top-node in `Events` `TreeGroup`) with wide 2-column control sizing (`width = 1.6..1.85`) so German and English labels never truncate or squish subtrees.
  - Upgraded Scroll Area movers (`ParrotScrollAreasOffsetBox`) to `DIALOG` strata with dark-gold styling, center crosshair alignment guides (`+`), **1px / 10px directional nudge buttons (`◄ ▲ ▼ ►`)**, Right-Click to lock, and realistic multi-school combat preview bursts.
  - Upgraded Minimap launcher with an interactive `LibQTip-1.0` tooltip displaying live AddOn status, active profile, CombatLog/Fallback engine mode, clickable quick-action rows, and mouse shortcuts (`Left-Click` config, `Right-Click` unlock/lock anchors, `Middle-Click` demo burst, `Shift-Click` toggle).
- **Expanded Retail 12.x (`Midnight`) Fallback Engine & Automatic Class Procs (`Code/CombatFeedFallback.lua`, `Code/Triggers.lua`)**:
  - Expanded `CombatFeedFallback.lua` with `UNIT_COMBAT` avoidance/mitigation events (`DODGE`, `PARRY`, `MISS`, `BLOCK`, `ABSORB`, `RESIST`, `IMMUNE`, `DEFLECT`, `EVADE`, `REFLECT`) for player, target, and pet, pet melee/healing tracking, dynamic recent-cast DoT/HoT aura attribution across all classes, spell-school caching in `C_DamageMeter` polling, and taint-safe `UNIT_AURA` diffing (`Buff/Debuff gains`, `stack gains`, `fades`).
  - Added zero-setup **Automatic Class Proc Alerts** (`SPELL_ACTIVATION_OVERLAY_GLOW_SHOW`) in `Code/Triggers.lua` with sticky `LibCustomGlow` highlights, configurable proc cooldown, scroll area, color, and spell ignore filter across Classic SoD, Cata, MoP, and Retail Midnight.
- **Smart Raid/AoE Anti-Spam, Killing Blow Glow, Coin Icons, Loot Quality Filter & Renown/Honor (`Code/CombatEvents.lua`, `Data/CombatEvents.lua`, `Data/Loot.lua`, `Data/PointGains.lua`)**:
  - Added **Smart Raid & AoE Anti-Spam** controls: dynamic AoE throttle window widening during dense multi-target bursts (`>12 hits/sec`) and gear-scaling `% Max HP` minimum damage/healing filters (`0%–5%`).
  - Added spell/skull icon support and automatic `LibCustomGlow` highlights on **Player & NPC Killing Blows**.
  - Added inline **Gold / Silver / Copper Coin Icons** (`lootCoinIcons`), **Minimum Loot Quality** filter (`minLootQuality`), and automatic quality-colored glow on **Epic+** item drops in `Data/Loot.lua`.
  - Added **PvP Honor Gains** (`CHAT_MSG_COMBAT_HONOR_GAIN`) and Retail **Major Faction Renown Rank-Up** (`MAJOR_FACTION_RENOWN_LEVEL_CHANGED`) celebration alerts in `Data/PointGains.lua`.
- **Profile & Custom Trigger Sharing (`Code/Share.lua`, `.pkgmeta`, `embeds.xml`)**:
  - Embedded `AceSerializer-3.0`, `LibDeflate`, `LibWindow-1.1`, and `LibQTip-1.0` and added compressed `!PAR1!P!...` (full profile) and `!PAR1!T!...` (custom triggers) import/export strings (`/parrot share`).
- **Standardized GitHub CI/CD & Packaging**: Added `.github/workflows/quality.yml`, `.github/workflows/release.yml`, `.github/FUNDING.yml`, issue/PR templates, `.pkgmeta` (GitHub upstreams, separated `Interface-Forever` & `Interface-Titan` TOC headers), `.gitignore`, and `.gitattributes`.

### Changed
- **Hardware Crit Scaling & Child Content Scaling (`Code/Display.lua`, `Data/AnimationStyles.lua`)**: Replaced per-frame `FontString:SetFont(...)` re-rasterization in `Pow` / `Pow 2` with smooth `SetScale` zoom curves on a centered child `content` frame so zoom animations never shift `SetPoint` screen offsets or stutter glyph atlases, and expanded font size sliders up to `48pt`.
- **Triggers (`Code/Triggers.lua`)**: Filtered class and specialization options dynamically to classes available in the active WoW expansion, and silently auto-disabled default triggers whose spell IDs do not exist in the current client instead of printing chat warnings on startup.

### Fixed
- **Frostfire School Color & `Action` Scale Leak (`Data/CombatEvents.lua`, `Data/AnimationStyles.lua`, `Code/Display.lua`)**: Fixed `FrostFire` vs `Frostfire` key mismatch preventing Frostfire spells from coloring properly, fixed `Action` / `Action Sticky` leaking `frame.startY` and `SetScale` onto recycled frames, and guarded `Sprinkler` slice math against zero-division.
- **Retail 12.0+ (Midnight) & Forever Secret Value Crashes (`Parrot2 #135`, `Parrot3`, `Parrot3 #1`)**:
  - Added `Compat.IsSecretValue`, `Compat.SafeNumber`, `Compat.SafeUnitName`, and `Compat.SafeUnitGUID` guards across `Code/Polyfills.lua`, `Data/Cooldowns.lua`, `Data/CombatEvents.lua`, `Data/Auras.lua`, `Data/PointGains.lua`, `Data/TriggerConditions.lua`, and `Code/CombatEvents.lua`.
  - Replaced `text:gsub("(%b[])", handler)` with a two-pass secret-safe tag substitution engine (`replaceTags` in `Code/CombatEvents.lua`) that resolves non-secret tags and strips `__NONAME__` placeholders first, then concatenates secret tag values (`<secret number>` / `<secret string>`) using `..` instead of `string.gsub` or `table.concat`, fixing `Parrot/Code/CombatEvents.lua:2114: invalid replacement value (a secret)`.
  - Guarded `Display_Update` and `isOverlapping` (`Code/Display.lua`) with `Compat.SafeNumber` when reading `FontString:GetWidth()`, `GetHeight()`, and frame bounds (`GetLeft`/`GetRight`/`GetTop`/`GetBottom`) on frames rendering secret strings.
  - Tested relational and equality comparisons (`value > -1 and value == value`) inside `pcall` in `Compat.IsSecretValue` and returned `nil, nil` from `Compat.GetSpellCooldown`, `Compat.GetSpellBookItemCooldown`, and `Compat.GetInventoryItemCooldown` when `startTime` or `duration` is a `<secret number>`, preventing `attempt to compare local 'start' (a secret number value)`.
- **Taint Isolation & Performance (`Code/Parrot.lua`, `Code/CombatEvents.lua`, `Code/Display.lua`)**:
  - Added private event dispatch (`Parrot.Events`) and filtered `"AceEvent-3.0"` out of `NewAddon` and `Parrot:NewModule` mixin lists so all Parrot modules exclusively use `Parrot.Events` without registering in shared `AceEvent-3.0` embeds.
  - Added dedicated `PLAYER_LOGIN` registration for `COMBAT_LOG_EVENT_UNFILTERED`, early exit + lazy table allocation in `HandleCombatlogEvent`, and overlap-only list allocation in `Display_Update`.
- **`C_Timer.After duration is too large` Crash (`Parrot2 #112`)**: Validated and clamped cooldown timer durations (`0 < remaining <= 3600`) in `Data/Cooldowns.lua`.
- **Classic / TBC / Wrath / Cata Cooldown Tracking (`Parrot2 #81`, `#78`, `Parrot3`)**: Called `ResetSpells()` on `OnEnable()` and `PLAYER_ENTERING_WORLD`, prevented empty spellbook tabs from aborting tab iteration early, and included non-passive active spells from Spellbook Tab 1 (such as Classic racial abilities).
- **`Outgoing damage` & `Outgoing cast` Trigger Conditions (`Parrot2 #95`)**: Fixed `Outgoing damage` primary trigger condition checking `dstGUID == playerGUID` instead of `srcGUID == playerGUID`, and added `SPELL_CAST_SUCCESS` to `Outgoing cast` and `Incoming cast` so non-damaging abilities trigger properly.
- **Uncached Item & Currency Fallbacks (`Parrot2 #130`, `#83`, `Parrot3`)**: Added link-text and `GetItemIconByID` fallbacks in `Data/Loot.lua`, `Data/Cooldowns.lua`, and `Data/PointGains.lua` when `GetItemInfo` or `GetCurrencyInfoFromLink` returns `nil` for uncached items.
- **Floating Combat Text CVar Control (`Parrot2 #85`, `Parrot3`)**:
  - Enabled `gameText` (`Control game options`) by default with `gameSelf = false`, `gameDamage = false`, `gamePetDamage = false`, and `gameHealing = false` (plus one-time profile migration `fctDefaultsMigratedV1`) so Blizzard's built-in damage, healing, and scrolling combat numbers are suppressed automatically out of the box.
  - Updated `setFCT` to set both base CVars (`floatingCombatTextCombatDamage`, `enableFloatingCombatText`, etc.), `_v2` CVars, and legacy aliases (`CombatDamage`, `CombatHealing`, `CombatLogPeriodicSpells`, `PetMeleeDamage`, `PetSpellDamage`), re-applied `UpdateFCT()` on `PLAYER_ENTERING_WORLD`, and unregistered/hid `_G.CombatText` when `gameSelf` is disabled.
  - Deferred `SetCVar` calls during `InCombatLockdown()` until `PLAYER_REGEN_ENABLED` and synchronized backing globals (`SHOW_COMBAT_TEXT`, `COMBAT_TEXT_SHOW_*`).
- **Elemental Melee Coloring & Spell Icon Overrides (`Parrot2 #88`, `#89`, `#99`)**: Used `coloredDamageAmount` on `Incoming`/`Outgoing` `Melee damage` and added Classic/TBC/Wrath Shaman Windfury, Flametongue, Fire Nova Totem, and Ancestral Awakening icon overrides.
- **Monk `Jade Walk` Aura Refresh Spam (`Parrot2 #126`)**: Suppressed `SPELL_AURA_REFRESH` spam for `Jade Walk` (`450552`) in `Data/Auras.lua`.
- **Lua 5.1 Environment Sandboxing (`Code/Polyfills.lua`, `Code/Parrot.lua`, `Code/Triggers.lua`, `Code/CombatEvents.lua`)**: Fixed `load(code, name, "t", env)` ignoring the `env` parameter in WoW's Lua 5.1 VM by using `loadstring` + `setfenv` via `Compat.LoadChunk`.
- **Reputation Gain Crash on Classic/TBC/Wrath/Cata/MoP (`Code/Parrot.lua`, `Data/PointGains.lua`)**: Guarded `Parrot.Deformat` and `_G.FACTION_STANDING_INCREASED_ACCOUNT_WIDE` against `nil` global format strings on non-Warband clients.
- **Expansion-Specific Blizzard Events (`Code/Parrot.lua`, `Code/Triggers.lua`, `Data/TriggerConditions.lua`, `Data/PointGains.lua`, `Data/Loot.lua`)**: Wrapped `RegisterEvent` calls in `pcall` and guarded events not present on all flavors (`SPELL_ACTIVATION_OVERLAY_SHOW`, `CHAT_MSG_CURRENCY`, `PLAYER_FOCUS_CHANGED`, `PET_BAR_HIDEGRID`, `PLAYER_TALENT_UPDATE`, `CHARACTER_POINTS_CHANGED`).
- **Alternate Power & Power Type Enum Fallbacks (`Data/CombatEvents.lua`, `Data/TriggerConditions.lua`)**: Added fallback `PowerType` table and nil-guards when `ALTERNATE_POWER_INDEX` or modern power types are absent in Classic clients.
- **Complete `enUS` & `deDE` Localization (`Locales/enUS.lua`, `Locales/deDE.lua`, `Code/ConfigWindow.lua`)**: Added all missing locale entries and German translations for `Profiles`, `Use ElvUI font`, `Warrior Stance`, `Not in Warrior Stance`, `Hide throttle text`, `Only show crits`, and Minimap icon options, and guarded sidebar `NAV_ITEMS` lookups with `rawget`.

---

# Legacy Changelog (Parrot2 / Parrot3 Upstream)

## [Legacy 1.0.0] - 2026-03-12

### Added
- `## Category: Combat` TOC directive (introduced in patch 11.1.0)

### Changed
- Updated TOC interface version to `120001` (WoW Midnight 12.0.1)

### Fixed
- **Auras.lua**: Replaced unusual `local FindAura do...end` forward-declaration pattern with standard `local function FindAura(...)` to prevent scope-resolution issues
- **Auras.lua**: Removed stray `)` in `defaultTag` of "Buff stack gains" event
- **Auras.lua**: Fixed `Unitname` tag translation using incorrect field `dstName` — changed to `recipientName` for consistency
- **Auras.lua**: Fixed nil crash in "Buff active" secondary condition when `param.stackcount` is not set
- **Parrot.lua**: Replaced deprecated `loadstring()` with `load()` in `GetPattern` (Lua 5.4 compatibility)
- **Parrot.lua**: Added nil-guard for `floatingCombatText*` CVars in `ResetFCT()`/`UpdateFCT()` — silently skips any CVars removed in WoW 12.0
- **Triggers.lua**: Replaced deprecated `loadstring()` + `setfenv()` with `load(chunk, name, mode, env)` for default trigger loading
- **Triggers.lua**: Fixed `C_Spell.DoesSpellExist()` receiving a string instead of a number — wrapped argument with `tonumber()`
- **Display.lua**: Added `Mixin(flasher, BackdropTemplateMixin)` — required since WoW 9.0 for `SetBackdrop`/`SetBackdropColor` on plain frames
- **Display.lua**: Fixed flash overlay alpha value passed as `255` instead of `1` (WoW uses 0–1 range)
- **CombatEvents.lua**: Added nil-guard around `UnitPowerBarID`/`GetUnitPowerBarStringsByID` calls for alternate power type parsing
- **Cooldowns.lua**: Replaced hardcoded `for tab = 1, 3` with `C_SpellBook.GetNumSpellBookSkillLines()` to correctly handle all spell book skill lines
