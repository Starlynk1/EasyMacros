# Easy Macros 1.0.5

- Fixed Forever `PetActionBar:SetShownBase` ADDON_ACTION_BLOCKED (including non-pet classes) caused by Spellbook post-click layout / UIPanel docking and micro-button tab writes.
- Spellbook button is secure-click only again; Blizzard UIPanel pushable handles docking while auto-layout is on.
- Macro list is sorted alphabetically (case-insensitive).
- Right-click a listed macro to Delete (with confirm), in addition to Rename.

# Easy Macros 1.0.4

- Fixed Spellbook button opening talents / flashing closed on Forever — uses the live spells micro button and a single secure click.
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
