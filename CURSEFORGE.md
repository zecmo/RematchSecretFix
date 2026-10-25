# Rematch Secret Fix

**Keeps [Rematch](https://www.curseforge.com/wow/addons/rematch) working on patch 12.1.**
Drop it in, delete it when Rematch ships an official 12.1 update. None of Rematch's
own files are touched.

Rematch 5.3.1 was last updated in January 2026 and declares Interface `120000`.
Patch 12.1 broke it in four ways — if any of these look familiar, this fixes them.

---

## Blank Rematch window

12.1 removed the `MouseIsOver` global that Rematch calls in 14 places, so the main
window draws empty.

*(This part is unieagle's [FixRematch](https://www.curseforge.com/wow/addons/fixrematch),
included here under MIT so you only need one addon. Completely harmless if you have
both installed.)*

## Team names missing, and the list behaving oddly

Names vanish from the Teams List, teams look like they have been **moved, renamed or
deleted**, and the list draws half-finished.

**Your teams are fine.** Nothing has been deleted and nothing needs restoring. 12.1
made some text values "secret" — unreadable to addons — and Rematch throws an error
part-way through drawing the list, leaving it half-rendered. It is a drawing failure,
not data loss. Your saved teams are untouched on disk.

## Auto-select doesn't work in pet battle dungeons

This one is silent — no error, it just stops working. Target a pet and nothing
happens: no target panel, no team loaded.

Inside instanced content, unit IDs are secret, so Rematch cannot tell what you are
targeting and switches target detection off entirely. The battle pet APIs are *not*
secret, so this addon recovers the pet's identity another way and auto-select works
again.

## Tooltips cut short

A single unreadable line would abandon the whole tooltip.

---

## Checking it works

```
/rsf
```

Prints exactly what took effect — which Rematch version is loaded and whether each
fix is applied. If something is wrong, that output is the most useful thing you can
include in a comment.

## Notes

- Works alongside FixRematch if you already have it.
- Each fix tries Rematch's own code first and only steps in if it fails, so they
  stop engaging by themselves once Rematch is updated.
- Harmless if Rematch isn't installed — it simply does nothing.

## Credits

- `MouseIsOver` shim — **unieagle**, from FixRematch, MIT licensed.
- Rematch — **gello3**. This addon contains none of its code.
