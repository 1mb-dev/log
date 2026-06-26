#!/usr/bin/env bash
# import-inbox.sh -- process inbox/<slug>/ entries into log article shape.
#
# Each inbox entry is a per-slug subdirectory containing:
#   <slug>/<slug>.md          markdown post with markgo frontmatter
#   <slug>/banner.png         (optional) rasterized banner image
#
# This script validates frontmatter, then moves artifacts into place:
#   inbox/<slug>/<slug>.md   -> articles/<slug>.md
#   inbox/<slug>/banner.png  -> static/img/banners/<slug>.png
#
# If an inbox entry also contains banner.html, it is ignored -- editorial
# HTML sources for banners live in the author repo, not tracked here.
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

# Run from the repo root regardless of invocation dir (paths below are relative).
cd "$(dirname "$0")/.."

INBOX_DIR="inbox"
ARTICLES_DIR="articles"
BANNERS_DIR="static/img/banners"

VALID_CATEGORIES=(Essays Thoughts Links AMA)
DATE_PATTERN='^"?[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})"?$'

# Tag taxonomy gates. The craftful pass (see todos/sketch-tag-hygiene.md
# and the matching arrays in scripts/tag-hygiene.sh) retired these
# synonyms and placeholders. Reintroducing one on import is almost
# always a regression -- a forgotten oncall/ops/devops collapse, or a
# too-generic career/building/pm placeholder. Edit both this list and
# the one in scripts/tag-hygiene.sh together when the taxonomy evolves.
BLOCKED_TAGS=(
    1mb-dev attention building career choices decisions devops drafting
    ecosystem feed introduction language launch mood oncall ops perfection
    planning pm policy practice product-design qa radio repo-hygiene
    scripture sdlc spec tagline
)

# Brand-new tags an import is allowed to introduce. Empty by default --
# operators add a tag here to acknowledge "yes I'm adding this to the
# taxonomy on purpose," then commit + run tag-hygiene.sh to confirm.
# Without an entry here, any tag not already in articles/ fails import.
NEW_TAGS_OK=(
    dependencies
)

TAG_CAP=4   # max tags per article. No minimum -- zero is acceptable
            # when nothing in the taxonomy genuinely fits.

DRY_RUN=0
FILTER=all
TARGET_SLUG=""

for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=1 ;;
        --text-only)   FILTER=text ;;
        --banner-only) FILTER=banner ;;
        --help|-h)     sed -n '2,24p' "$0" | sed -e 's/^# //' -e 's/^#//' ; exit 0 ;;
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

# Return every item from a YAML list block as one-per-line.
get_list_items() {
    awk -v key="$2" '
        $0 ~ "^"key":" { found = 1; next }
        found && /^[[:space:]]+-/ {
            sub(/^[[:space:]]+-[[:space:]]*/, "")
            print
            next
        }
        found && /^[a-zA-Z]/ { exit }
    ' <<< "$1"
}

# First non-empty line of the article body (after the frontmatter).
get_body_first_line() {
    awk '/^---$/{c++; next} c>=2 && NF { sub(/^[[:space:]]+/, ""); print; exit }' "$1"
}

# First text line of the description field. Handles a plain scalar and a
# block scalar (description: |- followed by indented lines).
get_description_first_line() {
    awk '
        /^---$/ { c++; next }
        c==1 && /^description:/ {
            v = $0; sub(/^description:[[:space:]]*/, "", v)
            if (v ~ /^[|>]/) { block = 1; next }
            gsub(/^["'\'']|["'\'']$/, "", v); print v; exit
        }
        c==1 && block && /^[[:space:]]+[^[:space:]]/ { sub(/^[[:space:]]+/, ""); print; exit }
        c==1 && block && /^[A-Za-z]/ { exit }
        c>=2 { exit }
    ' "$1"
}

# Build the set of tags already used by articles/*.md once per invocation.
CURRENT_TAGS_LOADED=0
CURRENT_TAGS=()
load_current_tags() {
    (( CURRENT_TAGS_LOADED == 1 )) && return
    local f fm tags_block t
    for f in "$ARTICLES_DIR"/*.md; do
        [[ -f "$f" ]] || continue
        fm=$(extract_frontmatter "$f")
        tags_block=$(get_list_items "$fm" "tags")
        while IFS= read -r t; do
            [[ -z "$t" ]] && continue
            in_array "$t" "${CURRENT_TAGS[@]+"${CURRENT_TAGS[@]}"}" || CURRENT_TAGS+=("$t")
        done <<< "$tags_block"
    done
    CURRENT_TAGS_LOADED=1
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

    local title date draft
    title=$(get_scalar "$fm" "title")
    date=$(get_scalar "$fm" "date")
    draft=$(get_scalar "$fm" "draft")

    [[ -n "$title" ]] || fail "$slug" "missing required frontmatter: title"
    [[ -n "$date" ]]  || fail "$slug" "missing required frontmatter: date"
    [[ -n "$draft" ]] || fail "$slug" "missing required frontmatter: draft"
    # description is optional: omit it and markgo auto-excerpts the body for
    # meta/OG/RSS. If present, it must not just echo the opening line (gate below).

    [[ "$date" =~ $DATE_PATTERN ]] || fail "$slug" "date not RFC3339: $date"
    [[ "$draft" == "false" ]]      || fail "$slug" "draft must be false (got: $draft)"

    # Body must not begin with a markdown H1 -- markgo renders the title from
    # frontmatter; a body H1 would duplicate it.
    local body_first
    body_first=$(awk '/^---$/{c++; next} c==2 && /^[^[:space:]]/{print; exit}' "$md_file")
    [[ "$body_first" =~ ^"# " ]] && fail "$slug" "body begins with '# ' heading (would duplicate title)"

    # Description gate: a present description must summarize the post, not echo
    # the opening line. On essays it renders as the visible dek above the body;
    # on every type it drives meta/OG/RSS/search. A verbatim repeat of line one
    # is the dek-repeats-lede anti-pattern (2026-06-03 description sweep).
    local desc_first open_first dn bn
    desc_first=$(get_description_first_line "$md_file")
    open_first=$(get_body_first_line "$md_file")
    dn=${#desc_first}; bn=${#open_first}
    if (( dn > 0 && bn > 0 )) && { [[ "${open_first:0:dn}" == "$desc_first" ]] || [[ "${desc_first:0:bn}" == "$open_first" ]]; }; then
        fail "$slug" "description repeats the opening line (\"$desc_first\"). Summarize the post instead, or omit the description field (markgo auto-excerpts the body for meta/OG/RSS)."
    fi

    local first_cat
    first_cat=$(get_first_list_item "$fm" "categories")
    [[ -n "$first_cat" ]] || fail "$slug" "missing required frontmatter: categories"
    in_array "$first_cat" "${VALID_CATEGORIES[@]}" || fail "$slug" "category not in vocabulary (got: $first_cat, allowed: ${VALID_CATEGORIES[*]})"

    # Tag taxonomy gates (see todos/sketch-tag-hygiene.md).
    local tag_block tags=() t
    tag_block=$(get_list_items "$fm" "tags")
    while IFS= read -r t; do
        [[ -n "$t" ]] && tags+=("$t")
    done <<< "$tag_block"

    (( ${#tags[@]} <= TAG_CAP )) || fail "$slug" "too many tags: ${#tags[@]} (max $TAG_CAP). Pick the most navigational. Got: ${tags[*]}"

    if (( ${#tags[@]} > 0 )); then
        load_current_tags
        for t in "${tags[@]}"; do
            in_array "$t" "${BLOCKED_TAGS[@]}" && fail "$slug" "tag '$t' is on the dropped-synonym blocklist (see scripts/import-inbox.sh BLOCKED_TAGS for rationale)"
            in_array "$t" "${CURRENT_TAGS[@]+"${CURRENT_TAGS[@]}"}" || in_array "$t" "${NEW_TAGS_OK[@]+"${NEW_TAGS_OK[@]}"}" || \
                fail "$slug" "tag '$t' is new -- add it to NEW_TAGS_OK in scripts/import-inbox.sh to acknowledge the taxonomy extension, or pick a tag already in the corpus"
        done
    fi

    local banner_field has_banner_field=0 has_banner_files=0
    banner_field=$(get_scalar "$fm" "banner")
    [[ -n "$banner_field" ]] && has_banner_field=1

    if [[ -f "$banner_html" ]]; then
        echo "  [skip] banner.html in $slug/ ignored -- HTML sources live in author repo, not tracked here." >&2
    fi

    if [[ -f "$banner_png" ]]; then
        has_banner_files=1
        [[ -s "$banner_png" ]] || fail "$slug" "banner.png is empty"
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
        [[ ! -e "$BANNERS_DIR/$slug.png" ]] || fail "$slug" "$BANNERS_DIR/$slug.png already exists"
    fi

    if (( DRY_RUN == 1 )); then
        echo "  would [$kind] $slug -> $ARTICLES_DIR/$slug.md$([[ $kind == banner ]] && echo " + banner")"
        return 0
    fi

    mkdir -p "$ARTICLES_DIR"
    (( has_banner_files == 1 )) && mkdir -p "$BANNERS_DIR"

    mv "$md_file" "$ARTICLES_DIR/$slug.md"
    if (( has_banner_files == 1 )); then
        mv "$banner_png" "$BANNERS_DIR/$slug.png"
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
    echo "  git add $ARTICLES_DIR $BANNERS_DIR 2>/dev/null; git commit -m 'content: ...'"
    echo "  git push && make deploy DOMAIN=log.1mb.dev"
fi
