#!/usr/bin/env bash
# ama.sh -- pull and publish AMA submissions for the markgo deployment.
#
# markgo stores reader AMA questions as draft articles (type: ama, draft: true)
# in the LIVE deployment's articles dir -- they never land in this clone until
# answered. This script pulls the pending ones and assembles the published
# answer locally, so the canonical copy lives in git (F4).
#
# Mechanics only. The judgment -- pick the decision/angle, draft the answer,
# voice + huddle review -- is the operator's; see todos/ritual-ama-process.md.
# Commit, push, and deploy stay gated to the operator. The one destructive
# remote action (clean-draft) is a separate, guarded subcommand.
#
# PII: AMA frontmatter carries asker_email. This repo is public, so `build`
# drops asker_email and keeps only the first-name `asker` (markgo renders it
# as "Asked by <name>" in the feed). The email never enters git.
#
# Load-bearing rules:
#   - Order: commit + push, then clean-draft, THEN deploy. Removing the stale
#     draft before deploy means the deploy's restart loads clean state -- skip
#     this and markgo serves the answer but keeps showing the question pending
#     until the next restart.
#   - Verify: after deploy, `ama.sh list` must read 0 pending. That's the proof
#     the draft is gone (and its email with it) server-side.
#   - One publish path: answer via THIS flow, never markgo's /admin/ama "Answer"
#     button. The button edits the draft server-side and publishes without
#     touching git (F4) or stripping the email. If it ever gets used by mistake,
#     reconcile with `make pull-from-vps DOMAIN=<domain>`.
#
# SSH: defaults to root because the deploy creates loguser with --shell /bin/false
# (it cannot ssh). root only touches article files here. On a hardened box, set
# SSH_USER to a dedicated non-root ops account with access to the articles dir.
#
# Usage:
#   scripts/ama.sh list
#       List pending AMA drafts on the VPS: question, asker, slug, file.
#
#   scripts/ama.sh build --from <draft-slug> --slug <new-slug> --answer <file>
#       Pull the draft, write articles/<new-slug>.md: question in frontmatter,
#       answer in the body (markgo v3.20.0 format), draft:false, asker_email
#       stripped, slug replaced. --from is optional when exactly one AMA pends.
#
#   scripts/ama.sh clean-draft --from <draft-slug>
#       Remove the stale draft on the VPS (guarded: must be type:ama +
#       draft:true + matching slug). Run AFTER deploy publishes the answer.
#
# Forkers: set DOMAIN (and SSH_USER/DEPLOY_PATH if your layout differs).
# Defaults mirror the Makefile -- root@<domain>:/opt/<domain>.

set -euo pipefail

DOMAIN="${DOMAIN:-log.1mb.dev}"
SSH_USER="${SSH_USER:-root}"
DEPLOY_PATH="${DEPLOY_PATH:-/opt/$DOMAIN}"
SSH_TARGET="$SSH_USER@$DOMAIN"
REMOTE_ARTICLES="$DEPLOY_PATH/articles"
# Anchor the local articles dir to the repo root so `build` writes to the right
# place regardless of CWD. Not a `cd` (that would break a relative --answer path).
ARTICLES_DIR="$(cd "$(dirname "$0")/.." && pwd)/articles"

fail() { echo "ama: $*" >&2; exit 1; }

# Read the AMA question from frontmatter. markgo v3.20.0 stores it as
# `question:` (plain, double-quoted, or a YAML block scalar); the body holds the
# answer. Prints the question as plain text.
extract_question() {
    awk '
        NR==1 && $0=="---" { infm=1; next }
        infm && !inblock && $0=="---" { exit }
        inblock {
            if ($0 ~ /^[^ \t]/) exit                 # next key at col 0 ends the block
            line=$0; sub(/^[ \t]+/,"",line); print line; next
        }
        infm && $0 ~ /^question:[ \t]*[|>][-+0-9]*[ \t]*$/ { inblock=1; next }
        infm && $0 ~ /^question:[ \t]*/ {
            v=$0; sub(/^question:[ \t]*/,"",v)
            if (v ~ /^".*"$/)        { v=substr(v,2,length(v)-2); gsub(/\\n/,"\n",v); gsub(/\\"/,"\"",v) }
            else if (v ~ /^'\''.*'\''$/) { v=substr(v,2,length(v)-2) }
            print v; exit
        }
    ' <<< "$1"
}

# Emit `question: <value>` as valid YAML — plain when safe (matching markgo's own
# yaml.v3 output), double-quoted when the value would otherwise mis-parse.
emit_question() {
    local s="$1" first="${1:0:1}" q quote=0
    [[ -z "$s" ]] && quote=1
    [[ "$s" == *$'\n'* ]] && quote=1
    [[ "$s" != "${s#[[:space:]]}" || "$s" != "${s%[[:space:]]}" ]] && quote=1
    [[ "$s" == *": "* || "$s" == *" #"* ]] && quote=1
    case "$first" in '!'|'&'|'*'|'?'|'|'|'>'|'%'|'@'|'`'|'"'|"'"|'#'|','|'['|']'|'{'|'}'|':'|'-'|' ') quote=1 ;; esac
    if (( quote )); then
        q=${s//\\/\\\\}; q=${q//\"/\\\"}; q=${q//$'\n'/\\n}
        printf 'question: "%s"\n' "$q"
    else
        printf 'question: %s\n' "$s"
    fi
}

# Remote: print "slug<TAB>file" for every pending (draft:true) AMA.
remote_pending() {
    ssh "$SSH_TARGET" "cd '$REMOTE_ARTICLES' && \
        for f in \$(grep -rls '^type: ama' . 2>/dev/null); do \
            grep -q '^draft: true' \"\$f\" || continue; \
            s=\$(awk -F': ' '/^slug:/{print \$2; exit}' \"\$f\"); \
            printf '%s\t%s\n' \"\$s\" \"\$f\"; \
        done"
}

cmd_list() {
    local rows; rows=$(remote_pending)
    [[ -n "$rows" ]] || { echo "no pending AMA on $DOMAIN"; return 0; }
    echo "pending AMA on $DOMAIN:"
    echo ""
    while IFS=$'\t' read -r slug file; do
        [[ -n "$slug" ]] || continue
        local body asker
        body=$(ssh "$SSH_TARGET" "cat '$REMOTE_ARTICLES/${file#./}'")
        asker=$(awk -F': ' '/^asker:/{print $2; exit}' <<< "$body")
        local q; q=$(extract_question "$body")
        printf "  slug:   %s\n  asker:  %s\n  q:      %s\n  file:   %s\n\n" \
            "$slug" "${asker:-(none)}" "$q" "${file#./}"
    done <<< "$rows"
}

# Resolve the draft slug: explicit --from, or the sole pending one.
resolve_from() {
    local from="$1" rows; rows=$(remote_pending)
    [[ -n "$rows" ]] || fail "no pending AMA on $DOMAIN"
    if [[ -n "$from" ]]; then
        awk -F'\t' -v s="$from" '$1==s{print $2; found=1} END{exit !found}' <<< "$rows" \
            || fail "no pending AMA with slug '$from' on $DOMAIN"
        return
    fi
    local n; n=$(grep -c . <<< "$rows")
    (( n == 1 )) || fail "$n AMAs pending -- pass --from <draft-slug> (see: ama.sh list)"
    cut -f2 <<< "$rows"
}

cmd_build() {
    local from="" new_slug="" answer_file=""
    while (( $# )); do
        case "$1" in
            --from)   from="$2"; shift 2 ;;
            --slug)   new_slug="$2"; shift 2 ;;
            --answer) answer_file="$2"; shift 2 ;;
            *) fail "unknown build arg: $1" ;;
        esac
    done
    [[ -n "$new_slug" ]]    || fail "build needs --slug <new-slug>"
    [[ -n "$answer_file" ]] || fail "build needs --answer <file>"
    [[ -f "$answer_file" ]] || fail "answer file not found: $answer_file"
    [[ -s "$answer_file" ]] || fail "answer file is empty: $answer_file"
    [[ "$new_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "slug must be kebab-case: $new_slug"
    local out="$ARTICLES_DIR/$new_slug.md"
    [[ ! -e "$out" ]] || fail "$out already exists"

    local file; file=$(resolve_from "$from")
    local draft; draft=$(ssh "$SSH_TARGET" "cat '$REMOTE_ARTICLES/${file#./}'")

    local asker author date question
    asker=$(awk '/^asker:/{sub(/^asker:[[:space:]]*/,""); print; exit}'   <<< "$draft")
    author=$(awk '/^author:/{sub(/^author:[[:space:]]*/,""); print; exit}' <<< "$draft")
    date=$(awk '/^date:/{sub(/^date:[[:space:]]*/,""); print; exit}' <<< "$draft")
    question=$(extract_question "$draft")
    [[ -n "$question" ]] || fail "could not read question from draft frontmatter"

    {
        echo "---"
        [[ -n "$asker" ]]  && echo "asker: $asker"
        [[ -n "$author" ]] && echo "author: $author"
        [[ -n "$date" ]]   && echo "date: $date"
        echo "draft: false"
        emit_question "$question"
        echo "slug: $new_slug"
        echo "type: ama"
        echo "---"
        echo ""
        cat "$answer_file"
    } > "$out"

    echo "wrote $out (asker=${asker:-none}, asker_email dropped)"
    echo ""
    echo "Next (operator):"
    echo "  \$EDITOR $out                      # final read"
    echo "  git add $out && git commit && git push"
    echo "  scripts/ama.sh clean-draft --from $(awk -F': ' '/^slug:/{print $2; exit}' <<< "$draft")   # remove stale VPS draft FIRST"
    echo "  make deploy DOMAIN=$DOMAIN          # publishes; restart then loads clean state"
    echo "  scripts/ama.sh list                 # verify 0 pending"
}

cmd_clean_draft() {
    local from=""
    while (( $# )); do
        case "$1" in
            --from) from="$2"; shift 2 ;;
            *) fail "unknown clean-draft arg: $1" ;;
        esac
    done
    [[ -n "$from" ]] || fail "clean-draft needs --from <draft-slug>"
    [[ "$from" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "--from must be a slug (kebab-case): $from"
    ssh "$SSH_TARGET" "cd '$REMOTE_ARTICLES' && \
        f=\$(grep -rls '^slug: $from' . 2>/dev/null | head -1); \
        [ -n \"\$f\" ] || { echo 'ama: no draft with slug $from on remote' >&2; exit 1; }; \
        grep -q '^type: ama' \"\$f\" && grep -q '^draft: true' \"\$f\" \
            || { echo \"ama: guard failed -- \$f is not a pending AMA draft\" >&2; exit 1; }; \
        rm -v \"\$f\""
    echo "removed stale draft for $from on $DOMAIN"
    echo "restart markgo so it drops from /admin/ama (deploy does this; else: ssh $SSH_TARGET systemctl restart log)"
}

[[ $# -gt 0 ]] || fail "usage: ama.sh {list|build|clean-draft} (see header)"
sub="$1"; shift
case "$sub" in
    list)        cmd_list "$@" ;;
    build)       cmd_build "$@" ;;
    clean-draft) cmd_clean_draft "$@" ;;
    -h|--help)   sed -n '2,48p' "$0" | sed -e 's/^# //' -e 's/^#//' ;;
    *) fail "unknown subcommand: $sub (list|build|clean-draft)" ;;
esac
