#!/usr/bin/env bash
#
# Package a WoW addon for release.
#
#   ./build.sh            package the addon folder found next to this script
#   ./build.sh MyAddon    package a specific folder, when the repo holds several
#
# Expects the usual layout: a folder beside this script whose name matches the
# .toc inside it, e.g. MyAddon/MyAddon.toc. The version in the .toc names the
# archive, so bump it there and nowhere else.
#
# Produces <Addon>-v<Version>.zip with no macOS metadata, and refuses to hand
# over an archive containing junk that gets addons rejected.

set -euo pipefail
cd "$(dirname "$0")"

die() { printf '\033[31mERROR\033[0m  %s\n' "$*" >&2; exit 1; }
ok()  { printf '\033[32mok\033[0m     %s\n' "$*"; }
note(){ printf '       %s\n' "$*"; }

# Junk that must never reach the archive. The first list is for `zip -x`,
# the second is the grep used to verify the result.
EXCLUDES=( '*.DS_Store' '*__MACOSX*' '*/._*' '._*' '*Thumbs.db' '*desktop.ini'
           '*.orig' '*.rej' '*.swp' '*/.git/*' '*.gitignore' )
JUNK_RE='\.DS_Store|__MACOSX|/\._|^\._|Thumbs\.db|desktop\.ini|\.orig$|\.rej$|\.swp$|/\.git/'

# ---------------------------------------------------------------- find addon
ADDON="${1:-}"
if [ -z "$ADDON" ]; then
    for dir in */; do
        dir="${dir%/}"
        if [ -f "$dir/$dir.toc" ]; then
            [ -z "$ADDON" ] || die "several addon folders here ($ADDON, $dir) - name one: ./build.sh $dir"
            ADDON="$dir"
        fi
    done
fi
[ -n "$ADDON" ] || die "no <folder>/<folder>.toc found beside this script"
ADDON="${ADDON%/}"
TOC="$ADDON/$ADDON.toc"
[ -f "$TOC" ] || die "missing $TOC (the .toc must share the folder's name)"
ok "addon: $ADDON"

# ------------------------------------------------------------------ read toc
tocfield() {
    grep -i "^## $1:" "$TOC" | head -1 | sed "s/^## [^:]*: *//" | tr -d '\r' | sed 's/ *$//'
}
VERSION="$(tocfield Version)"
INTERFACE="$(tocfield Interface)"
[ -n "$VERSION" ] || die "no '## Version:' in $TOC"
[ -n "$INTERFACE" ] || die "no '## Interface:' in $TOC"
case "$VERSION" in *[!0-9.]*) die "version '$VERSION' should be digits and dots only";; esac
ok "version: $VERSION"
ok "interface: $INTERFACE"

# Every file the .toc loads must actually exist, or the addon breaks silently
missing=0
while IFS= read -r line; do
    line="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    case "$line" in ''|'#'*) continue;; esac
    if [ ! -f "$ADDON/$line" ]; then
        printf '\033[31mERROR\033[0m  .toc loads "%s" but %s/%s does not exist\n' "$line" "$ADDON" "$line" >&2
        missing=1
    fi
done < "$TOC"
[ "$missing" -eq 0 ] || die "fix the .toc file list above"
ok ".toc file list resolves"

# -------------------------------------------------------------- syntax check
LUAC=""
for c in luac luac5.5 luac5.4 luac5.1; do
    command -v "$c" >/dev/null 2>&1 && { LUAC="$c"; break; }
done
if [ -n "$LUAC" ]; then
    # Skip junk: an AppleDouble ._Foo.lua is not source and will never parse
    while IFS= read -r f; do
        "$LUAC" -p "$f" || die "Lua syntax error in $f"
    done < <(find "$ADDON" -name '*.lua' -type f ! -name '._*' -not -path '*/.git/*')
    ok "lua syntax ($LUAC)"
else
    note "no luac found, skipping syntax check (brew install lua)"
fi

# --------------------------------------------------------- warn about source
found_junk="$(find "$ADDON" \( -name '.DS_Store' -o -name '._*' -o -name 'Thumbs.db' \) || true)"
if [ -n "$found_junk" ]; then
    note "junk in the source folder (excluded from the zip, but worth deleting):"
    printf '         %s\n' $found_junk
fi

# ----------------------------------------------------------------- build zip
ZIP="$ADDON-v$VERSION.zip"
[ -f "$ZIP" ] && note "replacing existing $ZIP"
rm -f "$ZIP"

xargs_excludes=()
for pattern in "${EXCLUDES[@]}"; do xargs_excludes+=( -x "$pattern" ); done

# -X drops extended attributes and resource forks (the source of ._ files)
# -D omits directory entries, keeping the archive to just real files
zip -r -X -D "$ZIP" "$ADDON" "${xargs_excludes[@]}" >/dev/null
[ -f "$ZIP" ] || die "zip produced nothing"

# ---------------------------------------------------------------- verify zip
entries="$(unzip -Z1 "$ZIP")"
if printf '%s\n' "$entries" | grep -qiE "$JUNK_RE"; then
    printf '\033[31mERROR\033[0m  junk made it into %s:\n' "$ZIP" >&2
    printf '%s\n' "$entries" | grep -iE "$JUNK_RE" >&2
    rm -f "$ZIP"
    die "archive deleted rather than shipped"
fi
ok "no .DS_Store / __MACOSX / ._* / Thumbs.db"

# Everything must sit under the addon folder, or WoW will not load it
if printf '%s\n' "$entries" | grep -qv "^$ADDON/"; then
    printf '\033[31mERROR\033[0m  entries outside %s/:\n' "$ADDON" >&2
    printf '%s\n' "$entries" | grep -v "^$ADDON/" >&2
    rm -f "$ZIP"
    die "archive deleted rather than shipped"
fi
ok "every entry under $ADDON/"

printf '%s\n' "$entries" | grep -q "^$ADDON/$ADDON\.toc$" || die "$ADDON.toc missing from the archive"
ok "$ADDON.toc present"

printf '\n\033[32mbuilt\033[0m  %s  (%s)\n' "$ZIP" "$(du -h "$ZIP" | cut -f1 | tr -d ' ')"
printf '%s\n' "$entries" | sed 's/^/       /'
