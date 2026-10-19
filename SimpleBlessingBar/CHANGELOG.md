# Changelog

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

### Added
- The addon loads for paladins on WoW Forever and says so with its version at login, in the
  client's language. Every other class loads nothing.
- A movable bar with an aura, a Righteous Fury, a blessing and a Salvation button. Each is
  highlighted while it has something to cast.
- The blessing button blesses your group without any assignment: every member gets the
  first blessing on his class's priority list that no other paladin has given in
  Greater form or an equal or higher rank. Greater Blessings where they are stronger; between
  equals only in a raid, from three members of a class in range, while you carry a Symbol of
  Kings.
- The Salvation button gives Salvation to every member who is not a tank, Revoke to a tank
  carrying it, and in a raid Mass Salvation to a class with enough members lacking it.
- Low-level members get the highest rank that reaches them; nothing is offered that the game
  would refuse with "Target is too low level".
- Both buttons show how many casts are left and name the next one in their tooltip. In combat
  they keep the cast that was first when the fight started; one that must wait for the end of
  combat shows no highlight, and the tooltip says so.
- A Priorities tab: early renewal, 5 minutes before a blessing or Salvation of yours runs out
  by default; the aura list; the priority list of each class, reordered by drag and drop,
  with blessings switched off per class and "Enable all" to switch them on again; and the
  overview.
- A change of a list is cast at once, replacing your blessing of another kind.
- Righteous Fury is only highlighted while the game reports you as tank (a group's role
  check); otherwise its button is greyed.
- The overview, on the Priorities tab: every group member in two columns, sorted by class and
  named in its colour, his role marked, a paladin's aura, the blessings and Salvation he
  carries, yours marked, the one you would give next faint. A middle click on the minimap
  button opens it.
- The aura button casts the first aura of your list that no other paladin of your group runs,
  so paladins need not agree who runs which.
- A settings window, opened with `/sbb`, a middle click on the handle, the minimap button, the
  AddOn menu or the game's Options. General: language, hide in combat, hide the minimap button,
  scale, border, background color, orientation and growth direction, demo mode, Report bug,
  Reload UI. Tracking: show each of the four buttons, their highlight's color and speed, and
  the color of the blessing and Salvation buttons' count.
  Supplies: the Symbol of Kings warning threshold and colors, and the auto-buy. Order: the
  order of the four buttons. Priorities: see above. Macros: prepared for a later version.
- The blessing button shows your Symbols of Kings once you know a Greater Blessing, colored
  when they run low; at a vendor they are bought automatically up to a target, above a gold
  reserve.
- A minimap button, an AddOn menu entry and an entry in the game's Options.
- A bug report to copy into a GitHub issue, without character names or realm.
- The handle's tooltip names the lock state and what each click does.
- Demo mode plans a blessing and Salvation for every class and casts nothing; the chat says
  what a click would cast.
- `/sbb help`, `/sbb lock`, `/sbb reset` and `/sbb bug`.
