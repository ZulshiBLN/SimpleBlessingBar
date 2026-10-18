# Changelog

This file follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [0.1.0] - Unreleased

### Added
- The addon loads for paladins on WoW Forever and says so with its version at login, in the
  client's language. Every other class loads nothing.
- A movable bar with one button per class in your group. A left click blesses the next member
  of that class who lacks your blessing, as a Greater Blessing when you know it and carry a
  Symbol of Kings. Each button shows how many lack it.
- An aura button and a Righteous Fury button. Each is highlighted while what it casts is
  missing.
- Flyouts: a right click on the aura button or a class button opens your auras or blessings
  beside it. A click on one selects it for the button without casting, also in combat. A
  flyout closes 2 seconds after the mouse leaves it, and a left click on any button of the bar
  closes every open flyout.
- A settings window, opened with `/sbb`. General: language, hide in combat, scale, border,
  background color, orientation and growth direction, demo mode, Reload UI. Tracking: show the
  aura and Righteous Fury buttons, their highlight's color and speed, the count color, and the
  flyouts' automatic closing and its time.
- Demo mode shows every class with sample counts and casts nothing; the chat says what a click
  would cast.
- `/sbb help`, `/sbb lock` and `/sbb reset`.
