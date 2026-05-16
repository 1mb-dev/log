#!/usr/bin/env bash
# import-inbox.sh -- process inbox/<slug>/ entries into log article shape.
#
# Each inbox entry is a per-slug subdirectory containing:
#   <slug>/<slug>.md          markdown post with markgo frontmatter
#   <slug>/banner.png         (optional) rasterized banner image
#   <slug>/banner.html        (optional) editorial source of the PNG
#
# This script validates frontmatter, then moves artifacts into place:
#   inbox/<slug>/<slug>.md   -> articles/<slug>.md
#   inbox/<slug>/banner.png  -> static/img/banners/<slug>.png
#   inbox/<slug>/banner.html -> banner-sources/<slug>.html
#
# Source-agnostic: knows nothing about who dropped the entries. Halts on the
# first failed validation (explicit triage). Does not commit, push, or deploy
# -- operator runs git + make deploy after reviewing the summary.
#
# Usage:
#   scripts/import-inbox.sh                  process all entries
#   scripts/import-inbox.sh <slug>           process one entry
#   scripts/import-inbox.sh --dry-run        preview without moving files
#   scripts/import-inbox.sh --text-only      skip entries with banner files
#   scripts/import-inbox.sh --banner-only    skip text-only entries

set -euo pipefail

INBOX_DIR="inbox"
ARTICLES_DIR="articles"
BANNERS_DIR="static/img/banners"
SOURCES_DIR="banner-sources"

VALID_CATEGORIES=(Essays Thoughts Links AMA)
DATE_PATTERN='^"?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})"?$'

DRY_RUN=0
FILTER=all
TARGET_SLUG=""

for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=1 ;;
        --text-only)   FILTER=text ;;
        --banner-only) FILTER=banner ;;
        --help|-h)     sed -n '2,23p' "$0" | sed 's/^# \?//' ; exit 0 ;;
        --*)           echo "unknown flag: $arg" >&2 ; exit 2 ;;
        *)             TARGET_SLUG="$arg" ;;
    esac
done

fail() {
    echo "FAIL [$1]: $2" >&2
    exit 1
}

extract_frontmatter() {
    awk '/^---$/{c++; next} c==1{print} c==2{exit}' "$1"
}

get_scalar() {
    awk -v key="$2" '
        $0 ~ "^"key":" {
            sub("^"key":[[:space:]]*", "")
            gsub(/^"|"$/, "")
            print
            exit
        }
    ' <<< "$1"
}

get_first_list_item() {
    awk -v key="$2" '
        $0 ~ "^"key":" { found = 1; next }
        found && /^[[:space:]]+-/ {
            sub(/^[[:space:]]+-[[:space:]]*/, "")
            print
            exit
        }
        found && /^[a-zA-Z]/ { exit }
    ' <<< "$1"
}

in_array() {
    local needle="$1"; shift
    for hay in "$@"; do
        [[ "$hay" == "$needle" ]] && return 0
    done
    return 1
}

process_entry() {
    local slug="$1"
    local entry_dir="$INBOX_DIR/$slug"
    local md_file="$entry_dir/$slug.md"
    local banner_png="$entry_dir/banner.png"
    local banner_html="$entry_dir/banner.html"

    [[ -d "$entry_dir" ]] || fail "$slug" "entry dir not found: $entry_dir"
    [[ -f "$md_file" ]]   || fail "$slug" "markdown not found: $md_file"

    local fm
    fm=$(extract_frontmatter "$md_file")
    [[ -n "$fm" ]] || fail "$slug" "frontmatter empty or unterminated"

    local title description date draft
    title=$(get_scalar "$fm" "title")
    description=$(get_scalar "$fm" "description")
    date=$(get_scalar "$fm" "date")
    draft=$(get_scalar "$fm" "draft")

    [[ -n "$title" ]]       || fail "$slug" "missing required frontmatter: title"
    [[ -n "$description" ]] || fail "$slug" "missing required frontmatter: description"
    [[ -n "$date" ]]        || fail "$slug" "missing required frontmatter: date"
    [[ -n "$draft" ]]       || fail "$slug" "missing required frontmatter: draft"

    [[ "$date" =~ $DATE_PATTERN ]] || fail "$slug" "date not RFC3339: $date"
    [[ "$draft" == "false" ]]      || fail "$slug" "draft must be false (got: $draft)"

    local first_cat
    first_cat=$(get_first_list_item "$fm" "categories")
    [[ -n "$first_cat" ]] || fail "$slug" "missing required frontmatter: categories"
    in_array "$first_cat" "${VALID_CATEGORIES[@]}" || fail "$slug" "category not in vocabulary (got: $first_cat, allowed: ${VALID_CATEGORIES[*]})"

    local banner_field has_banner_field=0 has_banner_files=0
    banner_field=$(get_scalar "$fm" "banner")
    [[ -n "$banner_field" ]] && has_banner_field=1

    if [[ -f "$banner_png" && -f "$banner_html" ]]; then
        has_banner_files=1
        [[ -s "$banner_png" ]]  || fail "$slug" "banner.png is empty"
        [[ -s "$banner_html" ]] || fail "$slug" "banner.html is empty"
        grep -q '<html' "$banner_html" || fail "$slug" "banner.html missing <html> tag"
    fi

    if (( has_banner_field == 1 && has_banner_files == 0 )); then
        fail "$slug" "frontmatter declares banner: $banner_field, but banner.png/banner.html missing"
    fi
    if (( has_banner_field == 0 && has_banner_files == 1 )); then
        fail "$slug" "banner.png/banner.html present but frontmatter has no banner field"
    fi

    local kind=text
    (( has_banner_files == 1 )) && kind=banner

    case "$FILTER" in
        text)   [[ $kind == banner ]] && { echo "  skip (filter=text) $slug"; return 0; } ;;
        banner) [[ $kind == text ]]   && { echo "  skip (filter=banner) $slug"; return 0; } ;;
    esac

    [[ ! -e "$ARTICLES_DIR/$slug.md" ]] || fail "$slug" "$ARTICLES_DIR/$slug.md already exists"
    if (( has_banner_files == 1 )); then
        [[ ! -e "$BANNERS_DIR/$slug.png" ]]  || fail "$slug" "$BANNERS_DIR/$slug.png already exists"
        [[ ! -e "$SOURCES_DIR/$slug.html" ]] || fail "$slug" "$SOURCES_DIR/$slug.html already exists"
    fi

    if (( DRY_RUN == 1 )); then
        echo "  would [$kind] $slug -> $ARTICLES_DIR/$slug.md$([[ $kind == banner ]] && echo " + banner")"
        return 0
    fi

    mkdir -p "$ARTICLES_DIR"
    (( has_banner_files == 1 )) && mkdir -p "$BANNERS_DIR" "$SOURCES_DIR"

    mv "$md_file" "$ARTICLES_DIR/$slug.md"
    if (( has_banner_files == 1 )); then
        mv "$banner_png"  "$BANNERS_DIR/$slug.png"
        mv "$banner_html" "$SOURCES_DIR/$slug.html"
    fi

    rmdir "$entry_dir" 2>/dev/null || true

    echo "  ok  [$kind] $slug"
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
}

[[ -d "$INBOX_DIR" ]] || { echo "no $INBOX_DIR/ -- nothing to do"; exit 0; }

slugs=()
if [[ -n "$TARGET_SLUG" ]]; then
    slugs=("$TARGET_SLUG")
else
    while IFS= read -r dir; do
        [[ -n "$dir" ]] && slugs+=("$dir")
    done < <(find "$INBOX_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed "s|^$INBOX_DIR/||" | sort)
fi

(( ${#slugs[@]} > 0 )) || { echo "no entries in $INBOX_DIR/ -- nothing to do"; exit 0; }

mode="processing"
(( DRY_RUN == 1 )) && mode="dry-run preview"
filter_note=""
[[ $FILTER != all ]] && filter_note=" (filter=$FILTER)"

echo "==> $mode ${#slugs[@]} entr$( (( ${#slugs[@]} == 1 )) && echo y || echo ies) from $INBOX_DIR/$filter_note"

PROCESSED_COUNT=0
for slug in "${slugs[@]}"; do
    process_entry "$slug"
done

echo "==> done: $PROCESSED_COUNT processed"

if (( DRY_RUN == 0 && PROCESSED_COUNT > 0 )); then
    echo ""
    echo "Next steps (manual):"
    [[ -f "$ARTICLES_DIR/_example.md" ]] && echo "  rm $ARTICLES_DIR/_example.md   # first real-content commit"
    echo "  build/markgo serve --port 3002   # local preview"
    echo "  git status                       # review changes"
    echo "  git add $ARTICLES_DIR $BANNERS_DIR $SOURCES_DIR 2>/dev/null; git commit -m 'content: ...'"
    echo "  git push && make deploy DOMAIN=log.1mb.dev"
fi
