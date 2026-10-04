# Recording sheet: voice clips for Summon Core

**The sheet and the takes are both in the repo, and the repo is public.** If Zennit looks, the lines meant to surprise him
(`zenit_land`, `zenit_refuse`, `zenit_win`) are spoiled. Everything is committed so nothing is lost; the surprise is only as
safe as he is incurious.

## How to record (one evening)

- One short take per file, **under 3 seconds**, mono, a quiet room, phone voice memo is fine. Say it twice, keep the better one.
- Convert to Ogg Vorbis (`ffmpeg -i take.m4a -ac 1 -af "highpass=f=80,loudnorm" -c:a libvorbis -q:a 4 wag_01_aaron.ogg`).
- Name each file `<category>_<NN>_<who>.ogg`: `wag_01_aaron.ogg`, `zenit_land_03_sam.ogg`. NN is 01, 02, 03... per category;
  `who` is whoever is speaking.
- Put them in `Media/clips/`, run `powershell -ExecutionPolicy Bypass -File tools\build_clip_manifest.ps1` (it writes
  `ClipList.lua` and warns about badly named files), commit the takes with `ClipList.lua`, then **restart WoW** (`/reload`
  does not pick up new media).
- Check with `/sc clip` (lists the categories) and `/sc clip zenit_land` (plays one). The addon picks a random clip per
  category and never plays the same one twice running, so **three or more per category** is where it starts to feel alive.

## The categories, with lines to start from

Take what is useful, change what is not. Funnier is the goal; the Index's dry voice is the house style.

### `wag`: plays instead of the built-in gag when someone opens the wrong tab
Who hears it: Zennit, on the Party tab; the party, on Zennit's tab.
- "Ah ah ah!"
- "Uh-uh. That one's not for you."
- "Nope. Nice try."
- "The Index says no."
- "Excuse me. Where do you think you're going?"
- "Ah ah ah. Ah ah ah ah."

### `zenit_land`: plays on Zennit's client when a friend's live summon of him arrives (the best surprise: only he hears it)
- "Oh no."
- "Here we go again."
- "Somebody wants me."
- "Is that... yes. It is."
- "Zennit. You have a visitor."
- "They've found you."
- "Not the portal."
- (a friend, flatly) "Zennit. It's us."

### `zenit_refuse`: when Zennit refuses a summon (his client and the summoner's)
- "Rude."
- "He's refused. Again."
- "Wow. Okay."
- "The Index is disappointed."
- "That's a no."
- "Fine. Fine!"

### `zenit_win`: when Zennit wins the dice
- "Of course he did."
- "The dice love him."
- "He rolled it!"
- "Somebody check the dice."
- "Unbelievable."
- "The Index checked the dice. They were dice."

### `ritual`: as a ritual of summoning begins (the caster's client)
- "Here we go."
- "Everybody on the portal."
- "Cake's in the oven."
- "Click the thing. Click the thing!"
- "Three of us. One of him."
- "For the Index."

### `narrator_weekopen`: when a finished week is announced
Best in the narrator's voice (Lewis, if he will).
- "The Index has counted."
- "Another week, filed in triplicate."
- "The Index regrets to inform you."
- "The week is closed. Form to follow."
- "The Index accepts most things."

## Where each one plays (so the take fits)

| Category | Plays when | Heard by |
|---|---|---|
| `wag` | Wrong tab opened | The person who opened it |
| `zenit_land` | A friend's live summon of Zennit arrives | Zennit only |
| `zenit_refuse` | Zennit refuses | Zennit and the summoner |
| `zenit_win` | Zennit wins the dice | Zennit and the summoner |
| `ritual` | A ritual begins | The caster |
| `narrator_weekopen` | A finished week is announced (about a minute after login) | Everyone |
