# Easy Macros 1.0.4

- Fixed Spellbook button opening talents / flashing closed on Forever — uses the live spells micro button, forces the Spellbook tab, and registers a single secure click.
- Added header cog menu: Unlock Frame, Show Tooltip, and Reset Frame (Blizzard panel layout).
- Unlock Frame detaches from UIPanel so the window can be dragged; Reset Frame restores docking.
- Show Tooltip (off by default) shows the spell tooltip when hovering created macros.
- Click a listed macro to load it into the preview; body text is editable; Create / Edit / Save flow for new and existing macros.
- Right-click a listed macro to Rename (max 16 characters); list spacing reflows for longer or shorter names.
- Macro list grows the frame downward by row (no scrollbar); cell width uses longest-word spacing and fills the list width.

# Easy Macros 1.0.3

- Fixed created-macro grid clipping the 8th icon off the frame; columns now fit inside the list viewport.
- Shortened the preview box by 10px and gave that height to the macro list so two rows show without cutoff.
- Fixed self buffs (e.g. Demon Armor / Demon Skin) incorrectly getting mouseover conditionals — uses Blizzard helpful/harmful/self and 0-range checks.
- Fixed summon / call-pet style spells being built as combat macros; neutral 0-range spells use a plain `/cast` (Blizzard APIs only, no spell list).

# Easy Macros 1.0.2

- Fixed character macro slot limit on Forever/Retail (30 slots, Classic + 12) so free-slot checks no longer stop at 18.
- Added combat lockdown: Easy Macros closes and refuses open/create/drop/drag while in combat to avoid interface errors.
