# Rematch Secret Fix

Keeps **Rematch 5.3.1** working on patch **12.1**, without touching any of
Rematch's own files. Drop it in, delete it when Rematch ships an official 12.1
update.

Rematch was last released in January 2026 and declares Interface `120000`.
Patch 12.1 broke it in four ways.

## What it fixes

**1. Blank main window.** 12.1 removed the `MouseIsOver` global and Rematch
calls it in 14 places. *(This part is unieagle's
[FixRematch / !RematchCompat](https://www.curseforge.com/wow/addons/fixrematch),
included here under MIT so you only need one addon. Harmless if you have both.)*

The other three come from **secret values** — 12.1 made a number of API results
opaque to addon code, so reading them raises an error.

**2. Teams List loses names.** A scanned NPC name can now be a secret string;
indexing it throws out of `GetNpcName` **mid-render**, so the list draws half
its rows. It looks exactly as though teams have been deleted or moved. They
have not — it is purely a draw failure and your saved data is untouched.

**3. Tooltips cut short.** One secret line aborted the entire tooltip copy.

**4. Target auto-select dead in dungeons.** This one is silent — nothing
errors. Unit GUIDs are secret inside instanced content, so Rematch cannot work
out an npcID, and target detection switches itself off: no target panel, no
auto-select, in exactly the pet battle dungeons you want it in.

Unit identity is secret, but the **battle pet APIs are not**, so for a wild pet
there is a way back:

```
UnitBattlePetSpeciesID -> C_PetJournal.GetPetInfoBySpeciesID -> companionID
```

and `companionID` is the same npcID a team is keyed on. Verified in a pet
battle dungeon: *Deviate Flapper* → species `1987` → companionID `116787`,
which is the exact key that team was saved under.

This only works for wild battle pets. For an ordinary NPC in an instance there
is no species to work from and identity is genuinely unavailable.

## How it behaves

Fixes 2–4 call Rematch's original function first and only act if it fails or
returns nothing. So they stop engaging by themselves the moment Rematch starts
handling secret values — no version checks to maintain — and Rematch keeps its
own name caching.

## Checking it is working

```
/rsf
```

Prints what actually took effect — whether `MouseIsOver` was restored or was
already there, which Rematch version is loaded, and whether each of the three
overrides is applied. It reads the live state rather than what the addon
remembers doing, so if another addon replaced a function afterwards it shows
as **NOT applied**.

Worth running before reporting a problem; "GetUnitNpcID NOT applied" is a far
more useful bug report than "auto-select doesn't work".

## Credits

- `MouseIsOver` shim — **unieagle**, from !RematchCompat, MIT.
- Rematch itself — **gello3**. This addon contains none of its code.
