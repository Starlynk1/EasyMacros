# Easy Macros 1.0.3

- Fixed created-macro grid clipping the 8th icon off the frame; columns now fit inside the list viewport.
- Shortened the preview box by 10px and gave that height to the macro list so two rows show without cutoff.
- Fixed self buffs (e.g. Demon Armor / Demon Skin) incorrectly getting mouseover conditionals — uses Blizzard helpful/harmful/self and 0-range checks.
- Fixed summon / call-pet style spells being built as combat macros; neutral 0-range spells use a plain `/cast` (Blizzard APIs only, no spell list).

# Easy Macros 1.0.2

- Fixed character macro slot limit on Forever/Retail (30 slots, Classic + 12) so free-slot checks no longer stop at 18.
- Added combat lockdown: Easy Macros closes and refuses open/create/drop/drag while in combat to avoid interface errors.

# Easy Macros 1.0.1

- Fixed Forever BugSack / ADDON_ACTION_BLOCKED on PetActionBar and MultiBar after creating a macro (CreateMacro + PickupMacro on the Create click).
- Fixed spellbook open from the addon retainting action bars — removed addon ShowUIPanel / ToggleSpellBook paths.
- Added a secure **Spellbook** button that clicks Blizzard’s micro button without tainting.
- Easy Macros now docks beside the spellbook like other Blizzard panels instead of closing when the book opens.
- Create flow clarified: drop a spell for preview, click **Create**, then drop the macro on your bar (or drag again from the created list).
- Restored `/petattack` on Hunter and Warlock combat macros.
