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
- **ElvUI Compatibility (`Parrot.toc`, `Code/Parrot.lua`, `Code/Display.lua`, `Code/ScrollAreas.lua`, `Code/Polyfills.lua`)**:
  - Added `ElvUI` and `AddOnSkins` to `OptionalDeps` in `Parrot.toc`.
  - Styled scroll area configuration movers (`ParrotScrollAreasOffsetBox`) with ElvUI's `Transparent` template when ElvUI is active.
  - Added automatic fallback to ElvUI's general/normal font (`E.db.general.font` / `E.media.normFont`) and trimmed icon texture coordinates (`E.TexCoords`) in `Code/Display.lua`.
  - Set default `AceConfigDialog` window size (`880x620`) for clean layout with ElvUI's Ace3 skin.
  - Fixed `DDI-Font` dropdown item recycling in `Code/Polyfills.lua` so `"Inherit"` entries always reset to the default font instead of retaining a recycled item's font face.
- **Warrior Stance Trigger Condition (`Parrot2 #93`)**: Added `Warrior Stance` (`Battle Stance`, `Defensive Stance`, `Berserker Stance`) as a secondary trigger condition in `Data/TriggerConditions.lua`.
- **Hide Throttle Text & Only Show Crits Options (`Parrot2 #47`, `#35`)**: Added `Hide throttle text` under `Events -> Throttle events` and `Only show crits` under `Events` options.
- **Minimap Button, Addon Compartment & Slash Subcommands**: Added `LibDBIcon-1.0` minimap button support (configurable in General options), Retail/Classic Addon Compartment handlers (`Parrot_OnAddonCompartmentClick`, `Enter`, `Leave`), and `/parrot test`, `/parrot toggle`, and `/parrot errors` subcommands.
- **Standardized GitHub CI/CD & Packaging**: Added `.github/workflows/quality.yml`, `.github/workflows/release.yml`, `.github/FUNDING.yml`, issue/PR templates, `.pkgmeta` (GitHub upstreams), `.gitignore`, and `.gitattributes`.

### Changed
- **Triggers (`Code/Triggers.lua`)**: Filtered class and specialization options dynamically to classes available in the active WoW expansion, and silently auto-disabled default triggers whose spell IDs do not exist in the current client instead of printing chat warnings on startup.

### Fixed
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
- **Floating Combat Text CVar Control (`Parrot2 #85`, `Parrot3`)**: Deferred `SetCVar` calls during `InCombatLockdown()` until `PLAYER_REGEN_ENABLED`, added `_v2` CVar auto-detection, synchronized backing globals (`SHOW_COMBAT_TEXT`, `COMBAT_TEXT_SHOW_*`), and invoked `CombatText_UpdateDisplayedMessages()`.
- **Elemental Melee Coloring & Spell Icon Overrides (`Parrot2 #88`, `#89`, `#99`)**: Used `coloredDamageAmount` on `Incoming`/`Outgoing` `Melee damage` and added Classic/TBC/Wrath Shaman Windfury, Flametongue, Fire Nova Totem, and Ancestral Awakening icon overrides.
- **Monk `Jade Walk` Aura Refresh Spam (`Parrot2 #126`)**: Suppressed `SPELL_AURA_REFRESH` spam for `Jade Walk` (`450552`) in `Data/Auras.lua`.
- **Lua 5.1 Environment Sandboxing (`Code/Polyfills.lua`, `Code/Parrot.lua`, `Code/Triggers.lua`, `Code/CombatEvents.lua`)**: Fixed `load(code, name, "t", env)` ignoring the `env` parameter in WoW's Lua 5.1 VM by using `loadstring` + `setfenv` via `Compat.LoadChunk`.
- **Reputation Gain Crash on Classic/TBC/Wrath/Cata/MoP (`Code/Parrot.lua`, `Data/PointGains.lua`)**: Guarded `Parrot.Deformat` and `_G.FACTION_STANDING_INCREASED_ACCOUNT_WIDE` against `nil` global format strings on non-Warband clients.
- **Expansion-Specific Blizzard Events (`Code/Parrot.lua`, `Code/Triggers.lua`, `Data/TriggerConditions.lua`, `Data/PointGains.lua`, `Data/Loot.lua`)**: Wrapped `RegisterEvent` calls in `pcall` and guarded events not present on all flavors (`SPELL_ACTIVATION_OVERLAY_SHOW`, `CHAT_MSG_CURRENCY`, `PLAYER_FOCUS_CHANGED`, `PET_BAR_HIDEGRID`, `PLAYER_TALENT_UPDATE`, `CHARACTER_POINTS_CHANGED`).
- **Alternate Power & Power Type Enum Fallbacks (`Data/CombatEvents.lua`, `Data/TriggerConditions.lua`)**: Added fallback `PowerType` table and nil-guards when `ALTERNATE_POWER_INDEX` or modern power types are absent in Classic clients.
- **Complete `enUS` & `deDE` Localization (`Locales/enUS.lua`, `Locales/deDE.lua`)**: Added all missing locale entries and German translations for `Warrior Stance`, `Not in Warrior Stance`, `Hide throttle text`, `Only show crits`, and Minimap icon options.

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
