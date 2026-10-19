# SimpleBlessingBar

A paladin blessing manager for **WoW Forever** (Classic content on the modern Retail client,
Interface 16001): it blesses your group by role, works around what other paladins already gave,
and casts Salvation, auras and Righteous Fury, with a modern look.

**Status: early development.** No release has been published yet. Setting a member's role and
editing the priority lists come later.

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
| Blessings | Cast the next blessing your group needs - highlighted while one is left | – |
| Salvation | Cast the next Salvation, Mass Salvation or Revoke your group needs - highlighted while one is left | – |
| Handle (the side the bar grows from; shows under the mouse) | Drag to move | Lock or unlock |

A middle click on the handle opens or closes the settings; hover it for a tooltip with the
lock state and its clicks.

**Aura flyout.** A right click on the aura button opens a row of your auras beside it; a second
right click closes it. A click on an icon **selects** it for the button without casting, **also
in combat**; the button's left click casts it. Hover an icon for the game's own tooltip. The
flyout closes 3 seconds after the mouse leaves it (see the settings), and a left click on any
button of the bar closes it. It opens towards the middle of the screen, or in the direction
chosen in the settings.

**Blessings.** Nothing is assigned: the addon decides for every member of your group.

- Every member has a role: tank, healer, melee, ranged or caster. A class with one possible
  role gets it; the others take the role the game reports for them, and their class default
  where it reports none. Out of a group the game reports no role, so yours is then your class
  default, melee.
- Each role has a priority list. A member gets the first blessing on its list that you know and
  no other paladin has given - in its Greater form, or in a rank at least as high as your best.
  A lower rank from someone else counts as missing.
- The game refuses a rank on a target more than ten levels below the level you learned it at.
  A low-level member therefore gets the highest rank that reaches him, and a blessing none of
  whose ranks reaches him is skipped for the next on his list.

  | Role | Priority |
  |---|---|
  | Tank | Kings, Might, Light, Wisdom |
  | Healer | Wisdom, Kings, Light, Might |
  | Melee | Might, Kings, Light, Wisdom |
  | Ranged | Kings, Wisdom, Light, Might |
  | Caster | Wisdom, Kings, Light, Might |

- A member is done once it carries a normal blessing of yours, or your Greater Blessing of
  the kind chosen for it: a paladin's second blessing on the same target replaces the first.
- **Greater or normal:** the stronger form you know is cast. Where both are equally strong, a
  Greater Blessing is cast only in a raid, when at least three members of a class in range lack
  it, and only while you carry a Symbol of Kings. A class gets at most one Greater Blessing from
  you, and it is cast before the normal ones it would overwrite.
- Once you know a Greater Blessing, the number in the middle of the blessing button is how many
  Symbols of Kings you carry: orange at or below the warning threshold, red at 0.
- Blessing of Sanctuary does not exist on WoW Forever.

**Salvation** goes to every member whose role is not tank. A tank carrying anyone's Salvation
gets Revoke. In a raid, a class gets Mass Salvation when the members of it in range who lack
Salvation, tanks not counted, are at least three plus the class's tanks; its tanks get Revoke
after it. Mass Salvation costs a Symbol of Kings. Members too low for Salvation, Mass Salvation
or Revoke - more than ten levels below the level you learned it at - are left out of it; Mass
Salvation and Greater Blessings count only the members they reach.

**Both buttons** show how many casts are left; with none left, no number shows and the highlight
stops. Hover a button to see what it casts next and on whom. Dead, offline and out-of-range
players are left out. A blessing is renewed once it has run out.

**In combat** the game hides who has which buff. The blessing and Salvation buttons keep the
cast that was first when the fight started - a Greater Blessing or Mass Salvation that would be
followed by casts that cannot happen in combat waits for the end of it. Clicking again casts it
again. Everything updates when combat ends.

## Settings

`/sbb`, a middle click on the handle, the minimap button, the AddOn menu next to the minimap,
or the button in the game's Options > AddOns open the settings window; Escape closes it. It
closes when combat starts and opens again when combat ends. Every change takes effect at once.

**General**
- Language: automatic (the client's) or any of the eleven, switched without a reload.
- Hide the bar in combat; hide the minimap button.
- Scale, 0.5 to 2.0: drag the slider or type a number (a comma works too).
- Border on or off, and the background color with its opacity - for the bar and the flyouts.
- Orientation (horizontal or vertical), the direction the bar grows, and the direction the
  flyouts open: automatic (towards the middle of the screen), or up or down for a horizontal
  bar, right or left for a vertical one.
- **Demo mode**: plans a blessing and Salvation for every class, each with its default role,
  shows a sample Symbol count, and treats every aura and blessing as learned. Clicks cast
  nothing; the chat says what would be cast. Demo mode is off after every login and cannot be
  switched in combat.
- Report bug, and Reload UI.

**Tracking**
- Aura and Righteous Fury: show the button or not, the highlight's color and its speed.
- Blessings: show the button or not, the highlight's color and speed, and the color of the
  count on the blessing and Salvation buttons.
- Salvation: show the button or not, the highlight's color and its speed.
- Flyouts: close automatically or not, and after how many seconds (1 to 5, 3 by default).

**Supplies**
- Symbol of Kings: the warning threshold (0 = no warning) and the warning and empty colors of
  its count.
- Auto-buy: at a vendor that sells them, Symbols of Kings are bought up to the amount you want
  in your bags, never spending below the gold reserve. Only once you know a Greater Blessing.
  The chat says what was bought and what it cost.

**Order**
- Drag the rows to reorder the bar's four buttons. "Default" restores aura, Righteous Fury,
  blessings, Salvation.

**Macros** - prepared; macros follow in a later version.

**Minimap button** - left click opens the settings, right click locks or unlocks the bar, drag
moves it around the minimap.

**Bug report** - `/sbb bug` or "Report bug" builds a report with the addon version, client,
language, settings and this addon's errors from BugSack, if installed. Copy it with Ctrl+C and
paste it as a new issue on GitHub. It contains no character name or realm.

## Chat commands

| Command | Action |
|---|---|
| `/sbb` | Open or close the settings window |
| `/sbb help` | List the commands |
| `/sbb lock` | Lock or unlock the bar |
| `/sbb reset` | Move the bar back to its start position (not in combat) |
| `/sbb bug` | Open the bug report |

## Languages

enUS, deDE, frFR, esES, esMX, itIT, ptBR, ruRU, koKR, zhCN, zhTW. The language follows the client
unless you choose another in the settings.

## Code structure

| File | Content |
|---|---|
| `Locales.lua` | All texts per language, locale switching |
| `Data.lua` | Spell IDs by rank, roles and their priority lists, defaults, the settings' schema version |
| `Core.lua` | Paladin check, chat output, language registry, secure attributes, saved variables, demo mode |
| `Blessings.lua` | Known spells and ranks, roles, group scan, what others gave, the blessing and Salvation planner |
| `Bar.lua` | Bar, handle, position and lock, layout, scale and look, Symbol count, refresh |
| `SelfBuffs.lua` | Aura and Righteous Fury buttons and their highlight |
| `Queue.lua` | Blessing and Salvation buttons, their queue, count and tooltip |
| `Flyout.lua` | Secure header, the aura flyout, demo mode's chat output |
| `Merchant.lua` | Symbol of Kings auto-buy |
| `Minimap.lua` | Minimap button, AddOn compartment, Options entry |
| `Report.lua` | Bug report window |
| `Settings.lua` | Settings window, tabs, widgets, color picker |
| `SettingsPages.lua` | The General, Tracking, Supplies, Order and Macros pages |
| `Main.lua` | Startup and chat commands |

Modules share code through the addon namespace (`ns`). Each file is its own Lua chunk, which keeps
every file far below Lua's limit of 200 local variables per chunk.

## Privacy and security

- Saved settings are validated at login, so damaged files cannot break the addon.
- No personal data is stored: only your choices and the bar's position.
- No addon messages are sent yet; what other paladins gave is read from the buffs themselves.
- The bug report is only shown to you, to copy; the addon sends nothing. It leaves out your
  character's names and realm.

## License

MIT, see [LICENSE](LICENSE). Author: ZulshiBLN.
