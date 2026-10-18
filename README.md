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
| Aura | Cast the chosen aura, highest rank you know - highlighted while none of your auras is up | Open the aura flyout |
| Righteous Fury | Cast Righteous Fury - highlighted while it is missing | – |
| One per class in your group | Bless the next member of that class who lacks your blessing - highlighted while someone lacks it | Open the blessing flyout |
| Handle (the side the bar grows from; shows under the mouse) | Drag to move | Lock or unlock |

A middle click on the handle opens or closes the settings; hover it for a tooltip with the
lock state and its clicks.

**Flyouts.** A right click opens a row of icons beside the button - your auras, or the
blessings you know - and closes any other flyout; a second right click closes it. A click on
an icon **selects** it for the button without casting, **also in combat**; the button's left
click casts it. Each blessing icon aims at the member of that class who lacks that blessing; a
greyed icon has nobody in range and does nothing. Hover an icon for the game's own tooltip.
A flyout closes 3 seconds after the mouse leaves it (see the settings), and a left click on
any button of the bar closes every open flyout. Flyouts open towards the middle of the
screen, or in the direction chosen in the settings.

- A class button shows the class, the blessing chosen for it and how many members of the class
  lack your blessing; with nobody lacking it, no number shows. Dead and offline players are
  not counted.
- The blessing is cast as a **Greater Blessing** when you know it and carry a Symbol of Kings,
  otherwise in the highest rank you know. With nobody lacking it, a click renews the blessing
  that runs out first.
- A greyed class button has no blessing chosen, or one you have not learned. It does nothing.
- **Salvation** goes only to members of your own party; Mass Salvation reaches the whole class.
- **In combat** the game hides who has which buff. The counts and the highlights keep their state
  from before the fight, and a click blesses the member chosen then - also after you pick
  another blessing from a flyout. Everything updates when combat ends.
- Blessing of Sanctuary does not exist on WoW Forever.

## Settings

`/sbb` opens the settings window; Escape closes it. It closes when combat starts and opens again
when combat ends. Every change takes effect at once.

**General**
- Language: automatic (the client's) or any of the eleven, switched without a reload.
- Hide the bar in combat.
- Scale, 0.5 to 2.0: drag the slider or type a number (a comma works too).
- Border on or off, and the background color with its opacity - for the bar and the flyouts.
- Orientation (horizontal or vertical), the direction the bar grows, and the direction the
  flyouts open: automatic (towards the middle of the screen), or up or down for a horizontal
  bar, right or left for a vertical one.
- **Demo mode**: shows a button for every class with sample counts, and every aura and
  blessing as if learned. Clicks cast nothing; the chat says what would be cast. Demo mode is
  off after every login and cannot be switched in combat.
- Reload UI.

**Tracking**
- Aura and Righteous Fury: show the button or not, the highlight's color and its speed.
- Blessings: the class buttons' highlight color and speed, and the color of their count.
- Flyouts: close automatically or not, and after how many seconds (1 to 5, 3 by default).

## Chat commands

| Command | Action |
|---|---|
| `/sbb` | Open or close the settings window |
| `/sbb help` | List the commands |
| `/sbb lock` | Lock or unlock the bar |
| `/sbb reset` | Move the bar back to its start position (not in combat) |

## Languages

enUS, deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW. The language follows the client
unless you choose another in the settings.

## Code structure

| File | Content |
|---|---|
| `Locales.lua` | All texts per language, locale switching |
| `Data.lua` | Spell IDs by rank, class order, defaults, the settings' schema version |
| `Core.lua` | Paladin check, chat output, language registry, secure attributes, saved variables, demo mode |
| `Blessings.lua` | Known blessings, rank and Greater choice, group scan, who lacks a blessing, targets |
| `Bar.lua` | Bar, handle, position and lock, layout, scale and look, class buttons, refresh |
| `SelfBuffs.lua` | Aura and Righteous Fury buttons and their highlight |
| `Flyout.lua` | Secure header, the aura and class flyouts, demo mode's chat output |
| `Settings.lua` | Settings window, tabs, widgets, color picker |
| `SettingsPages.lua` | The General and Tracking pages |
| `Main.lua` | Startup and chat commands |

Modules share code through the addon namespace (`ns`). Each file is its own Lua chunk, which keeps
every file far below Lua's limit of 200 local variables per chunk.

## Privacy and security

- Saved settings are validated at login, so damaged files cannot break the addon.
- No personal data is stored: only your choices and the bar's position.
- No addon messages are sent yet.

## License

MIT, see [LICENSE](LICENSE). Author: ZulshiBLN.
