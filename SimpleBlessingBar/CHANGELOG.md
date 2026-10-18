# Changelog

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

### Added
- The addon loads for paladins on WoW Forever and says so with its version at login, in the
  client's language. Every other class loads nothing.
- A movable bar with one button per class in your group. A left click blesses the next member
  of that class who lacks your blessing, as a Greater Blessing when you know it and carry a
  Symbol of Kings. Each button shows how many lack it and is highlighted while anyone does.
- An aura button and a Righteous Fury button. Each is highlighted while what it casts is
  missing.
- Flyouts: a right click on the aura button or a class button opens your auras or blessings
  beside it. A click on one selects it for the button without casting, also in combat. A
  flyout closes 3 seconds after the mouse leaves it, and a left click on any button of the bar
  closes every open flyout.
- A settings window, opened with `/sbb`, a middle click on the handle, the minimap button, the
  AddOn menu or the game's Options. General: language, hide in combat, hide the minimap button,
  scale, border, background color, orientation, growth and flyout direction, demo mode, Report
  bug, Reload UI. Tracking: show the aura and Righteous Fury buttons, their highlight's
  color and speed, the class buttons' highlight and count colors and highlight speed, and the
  flyouts' automatic closing and its time. Supplies: the Symbol of Kings warning threshold and
  colors, and the auto-buy. Order: the bar's order, the class buttons as one block with their
  own order inside. Macros: prepared for a later version.
- Class buttons show your Symbols of Kings once you know a Greater Blessing, colored when they
  run low; at a vendor they are bought automatically up to a target, above a gold reserve.
- A minimap button, an AddOn menu entry and an entry in the game's Options.
- A bug report to copy into a GitHub issue, without character names or realm.
- The handle's tooltip names the lock state and what each click does.
- Demo mode shows every class with sample counts and casts nothing; the chat says what a click
  would cast.
- `/sbb help`, `/sbb lock`, `/sbb reset` and `/sbb bug`.
