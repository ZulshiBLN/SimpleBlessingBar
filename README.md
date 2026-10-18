# SimpleBlessingBar

A paladin blessing manager for **WoW Forever** (Classic content on the modern Retail client,
Interface 16001): assign, coordinate and cast blessings, auras and Righteous Fury, with a modern
look.

**Status: early development.** No release has been published yet. The bar works for one
paladin; sharing assignments with other paladins comes later.

## Installation

Once a release is published it will be on GitHub, CurseForge and Wago. Until then, the addon can
only be installed by hand from this repository: copy the folder `SimpleBlessingBar` into
`Interface\AddOns` of your WoW Forever installation, so that
`Interface\AddOns\SimpleBlessingBar` holds `SimpleBlessingBar.toc`.

The addon loads for paladins only.

## The bar

| Button | Left click | Right click |
|---|---|---|
| Aura | Cast the chosen aura, highest rank you know - glows while none of your auras is up | Open the aura flyout |
| Righteous Fury | Cast Righteous Fury - glows while it is missing | – |
| One per class in your group | Bless the next member of that class who lacks your blessing | Open the blessing flyout |
| Handle (left edge) | Drag to move | Lock or unlock |

**Flyouts.** A right click opens a row of icons above the button - your auras, or the
blessings you know - and closes any other flyout; a second right click closes it. A click on
an icon casts it at once, **also in combat**, and the button keeps it from then on. Each
blessing icon aims at the member of that class who lacks that blessing; a greyed icon has
nobody in range and does nothing. Hover an icon for the game's own tooltip.

- A class button shows the class, the blessing chosen for it and how many members of the class
  lack your blessing. Dead and offline players are not counted.
- The blessing is cast as a **Greater Blessing** when you know it and carry a Symbol of Kings,
  otherwise in the highest rank you know. With nobody lacking it, a click renews the blessing
  that runs out first.
- A greyed class button has no blessing chosen, or one you have not learned. It does nothing.
- **Salvation** goes only to members of your own party; Mass Salvation reaches the whole class.
- **In combat** the game hides who has which buff. The counts and the glows keep their state
  from before the fight, and a click blesses the member chosen then - also after you pick
  another blessing from a flyout. Everything updates when combat ends.
- Blessing of Sanctuary does not exist on WoW Forever.

## Chat commands

| Command | Action |
|---|---|
| `/sbb` or `/sbb help` | List the commands |
| `/sbb lock` | Lock or unlock the bar |
| `/sbb reset` | Move the bar back to its start position (not in combat) |

## Languages

enUS, deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW. The language follows the client.

## Code structure

| File | Content |
|---|---|
| `Locales.lua` | All texts per language, locale switching |
| `Data.lua` | Spell IDs by rank, class order, defaults, the settings' schema version |
| `Core.lua` | Paladin check, chat output, secure attributes, saved variables |
| `Blessings.lua` | Known blessings, rank and Greater choice, group scan, who lacks a blessing, targets |
| `Bar.lua` | Bar, handle, position and lock, class buttons, refresh |
| `SelfBuffs.lua` | Aura and Righteous Fury buttons and their glow |
| `Flyout.lua` | Secure header, the aura and class flyouts |
| `Main.lua` | Startup and chat commands |

Modules share code through the addon namespace (`ns`). Each file is its own Lua chunk, which keeps
every file far below Lua's limit of 200 local variables per chunk.

## Privacy and security

- Saved settings are validated at login, so damaged files cannot break the addon.
- No personal data is stored: only your choices and the bar's position.
- No addon messages are sent yet.

## License

MIT, see [LICENSE](LICENSE). Author: ZulshiBLN.
