# SimpleBlessingBar

A paladin blessing manager for **WoW Forever** (Classic content on the modern Retail client,
Interface 16001): assign, coordinate and cast blessings, auras and Righteous Fury, with a modern
look.

**Status: early development.** Version 0.1.0 is the skeleton - the addon loads for paladins and
says so with its version at login. There is nothing to use yet, and no release has been
published.

## Installation

Once a release is published it will be on GitHub, CurseForge and Wago. Until then, the addon can
only be installed by hand from this repository: copy the folder `SimpleBlessingBar` into
`Interface\AddOns` of your WoW Forever installation, so that
`Interface\AddOns\SimpleBlessingBar` holds `SimpleBlessingBar.toc`.

The addon loads for paladins only.

## Languages

enUS, deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW. The language follows the client.

## Code structure

| File | Content |
|---|---|
| `Locales.lua` | All texts per language, locale switching |
| `Data.lua` | Spell IDs, layout constants, defaults, the settings' schema version |
| `Core.lua` | Paladin check, chat output, saved variables |
| `Main.lua` | Startup |

Modules share code through the addon namespace (`ns`). Each file is its own Lua chunk, which keeps
every file far below Lua's limit of 200 local variables per chunk.

## Privacy and security

- Saved settings are validated at login, so damaged files cannot break the addon.
- No personal data is stored.

## License

MIT, see [LICENSE](LICENSE). Author: ZulshiBLN.
