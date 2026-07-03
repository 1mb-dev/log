#!/usr/bin/env bash
# tag-hygiene.sh -- periodic audit of articles/ tag taxonomy.
#
# Reports drift from the canonical taxonomy decided in the craftful pass
# (todos/sketch-tag-hygiene.md, and codified inline below):
# blocked-synonym reintroduction, over-cap articles, brand-new tags
# introduced since the last canonical list, singletons that have
# graduated to multi-article status, and the current head/middle/tail
# distribution.
#
# Does not mutate articles. Reports only. Exits non-zero if a hard
# regression (blocked tag, over-cap article) is found.
#
# Run quarterly, before content commits, or any time the corpus feels
# noisy.
#
# Usage:
#   scripts/tag-hygiene.sh              full report
#   scripts/tag-hygiene.sh --quiet      only sections with findings
#   scripts/tag-hygiene.sh --json       machine-readable JSON

set -euo pipefail

cd "$(dirname "$0")/.."

QUIET=0
JSON=0
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=1 ;;
        --json)  JSON=1 ;;
        --help|-h)
            sed -n '2,21p' "$0" | sed -e 's/^# //' -e 's/^#//'
            exit 0
            ;;
        *) echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

# ----------------------------------------------------------------------------
# Canonical taxonomy is in Python heredoc below. When it changes:
#   1. Update the BLOCKED_TAGS / CANONICAL_TAGS lists below.
#   2. Mirror the same change in scripts/import-inbox.sh.
#   3. Note the rationale in todos/sketch-tag-hygiene.md or the relevant doc.
#
# Visual weighting on /tags is operator-tuned, not auto-calibrated. log's
# static/css/themes/1mb.css buckets .tag-cloud-item by data-count (currently
# 1-2 / 3-5 / 6+). When the head/mid/tail distribution below shifts
# meaningfully, revisit those bracket boundaries.
# ----------------------------------------------------------------------------

python3 - "$QUIET" "$JSON" <<'PY'
import os, re, sys, yaml, json
from collections import defaultdict

QUIET = sys.argv[1] == "1"
JSON_OUT = sys.argv[2] == "1"

# Tags retired by the craftful pass. Reintroducing any of these is almost
# always a regression -- a forgotten synonym (oncall vs ops) or a too-generic
# placeholder (career, building) the pass deliberately moved away from.
BLOCKED_TAGS = {
    "1mb-dev", "attention", "building", "career", "choices", "decisions",
    "devops", "drafting", "ecosystem", "feed", "introduction", "language",
    "launch", "mood", "oncall", "ops", "perfection", "planning", "pm",
    "policy", "practice", "product-design", "qa", "radio", "repo-hygiene",
    "scripture", "sdlc", "spec", "tagline",
}

# The 28-tag baseline (26 from craftful pass + dependencies + consistency).
CANONICAL_TAGS = {
    # 18 multi-article (load-bearing navigation)
    "philosophy", "solo", "community", "shipping", "observations", "builders",
    "contrasts", "craft", "definitions", "mindset", "reality", "solo-building",
    "accountability", "calm-design", "discipline", "identity", "maintenance",
    "ownership",
    # 8 promoted singletons (deliberate growth bets)
    "ai", "communication", "design", "engineering", "ethics", "open-source",
    "testing", "zero-stack",
    # post-baseline additions
    "dependencies", "consistency",
}

# Singletons by deliberate design vs. by accident.
PROMOTED_SINGLETONS = {
    "ai", "communication", "design", "engineering", "ethics", "open-source",
    "testing", "zero-stack",
}

TAG_CAP = 4  # max tags per article. No minimum -- zero is acceptable.

# ----------------------------------------------------------------------------
# Scan corpus
# ----------------------------------------------------------------------------

tag_count = defaultdict(int)
tag_articles = defaultdict(list)
article_tags = {}

for fn in sorted(os.listdir("articles")):
    if not fn.endswith(".md"):
        continue
    with open(f"articles/{fn}") as f:
        body = f.read()
    m = re.match(r"^---\n(.*?)\n---", body, re.S)
    if not m:
        continue
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        continue
    tags = fm.get("tags", []) or []
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",")]
    tags = [t.strip() for t in tags if t.strip()]
    slug = fn[:-3]
    article_tags[slug] = tags
    for t in tags:
        tag_count[t] += 1
        tag_articles[t].append(slug)

total_articles = len(article_tags)
total_tags = len(tag_count)

# ----------------------------------------------------------------------------
# Audit
# ----------------------------------------------------------------------------

blocked_findings = sorted(
    (t, sorted(tag_articles[t])) for t in tag_count if t in BLOCKED_TAGS
)
over_cap = sorted(
    (slug, tags) for slug, tags in article_tags.items() if len(tags) > TAG_CAP
)
new_tags = sorted(
    (t, sorted(tag_articles[t])) for t in tag_count
    if t not in CANONICAL_TAGS and t not in BLOCKED_TAGS
)
graduated = sorted(t for t in PROMOTED_SINGLETONS if tag_count.get(t, 0) >= 2)
retired = sorted(t for t in CANONICAL_TAGS if tag_count.get(t, 0) == 0)
zero_tag_articles = sorted(slug for slug, tags in article_tags.items() if not tags)
singletons = sorted(t for t in tag_count if tag_count[t] == 1)

# Distribution
head = sum(1 for c in tag_count.values() if c >= 5)
mid = sum(1 for c in tag_count.values() if 2 <= c <= 4)
tail = sum(1 for c in tag_count.values() if c == 1)

# ----------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------

if JSON_OUT:
    print(json.dumps({
        "total_articles": total_articles,
        "total_tags": total_tags,
        "distribution": {"head": head, "mid": mid, "tail": tail},
        "blocked_reintroductions": [
            {"tag": t, "articles": arts} for t, arts in blocked_findings
        ],
        "over_cap_articles": [
            {"slug": s, "tags": tags, "count": len(tags)} for s, tags in over_cap
        ],
        "new_tags_since_baseline": [
            {"tag": t, "count": len(arts), "articles": arts} for t, arts in new_tags
        ],
        "graduated_singletons": [
            {"tag": t, "count": tag_count[t]} for t in graduated
        ],
        "retired_canonical": retired,
        "zero_tag_articles": zero_tag_articles,
        "singletons": [
            {
                "tag": t,
                "promoted": t in PROMOTED_SINGLETONS,
                "article": tag_articles[t][0],
            }
            for t in singletons
        ],
    }, indent=2))
    sys.exit(0 if not blocked_findings and not over_cap else 1)


def section(title, has_findings, body):
    if not has_findings and QUIET:
        return
    print(f"\n## {title}\n")
    print(body)


from datetime import datetime, timezone
print(f"tag hygiene audit -- {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}")
print(f"corpus: {total_articles} articles, {total_tags} unique tags")

if not QUIET:
    print(f"\n## Distribution\n")
    print(f"  head (5+ articles):  {head} tags")
    print(f"  mid  (2-4 articles): {mid} tags")
    print(f"  tail (1 article):    {tail} tags")
    print(f"\n  Reminder: if your theme buckets .tag-cloud-item by data-count")
    print(f"  (see static/css/themes/1mb.css), revisit bracket boundaries")
    print(f"  when this distribution shifts meaningfully.")

# Blocked reintroductions
if blocked_findings:
    body = "\n".join(f"  x {t} (on: {', '.join(arts)})" for t, arts in blocked_findings)
    body += "\n\n  Action: remove these tags. They were retired in the craftful pass."
    section("Blocked synonym reintroductions (regression)", True, body)
elif not QUIET:
    section("Blocked synonym reintroductions", False, "  none -- clean.")

# Over-cap
if over_cap:
    body = "\n".join(f"  x {slug} ({len(tags)} tags): {', '.join(tags)}" for slug, tags in over_cap)
    body += f"\n\n  Action: prune to <= {TAG_CAP} most navigational tags."
    section(f"Articles over the {TAG_CAP}-tag cap", True, body)
elif not QUIET:
    section(f"Articles over the {TAG_CAP}-tag cap", False, "  none -- clean.")

# New tags
if new_tags:
    body = "\n".join(f"  + {t} ({len(arts)} article(s): {', '.join(arts)})" for t, arts in new_tags)
    body += "\n\n  Action: if it has earned its place (recurs across articles), add to CANONICAL_TAGS in both this script and scripts/import-inbox.sh. Otherwise consider rewriting the article to use an existing tag."
    section("Tags new since canonical baseline", True, body)
elif not QUIET:
    section("Tags new since canonical baseline", False, "  none -- corpus matches baseline.")

# Graduated
if graduated:
    body = "\n".join(f"  ↑ {t} (now {tag_count[t]} articles)" for t in graduated)
    body += "\n\n  Action: none required. Growth bets paying off. Note in next CHANGELOG taxonomy review."
    section("Promoted singletons that graduated", True, body)
elif not QUIET:
    section("Promoted singletons that graduated", False, "  none -- promoted singletons still singletons.")

# Retired canonical
if retired:
    body = "\n".join(f"  o {t}" for t in retired)
    body += "\n\n  Action: if intentional (corpus drift away from theme), remove from CANONICAL_TAGS. If accidental, an article that used to carry it was retagged."
    section("Canonical tags now empty", True, body)
elif not QUIET:
    section("Canonical tags now empty", False, "  none -- all canonical tags carry articles.")

# Zero-tag (reporting only -- intentional now)
if not QUIET and zero_tag_articles:
    body = "\n".join(f"  . {s}" for s in zero_tag_articles)
    section("Zero-tag articles (reporting only)", True, body)

# Singletons (reporting only)
if not QUIET:
    if singletons:
        lines = []
        for t in singletons:
            marker = "*" if t in PROMOTED_SINGLETONS else " "
            lines.append(f"  {marker} {t}  ->  {tag_articles[t][0]}")
        body = "\n".join(lines)
        body += "\n\n  '*' = promoted (deliberate growth bet). Others are recent additions or candidates for next pass."
        section("Singletons (reporting only)", True, body)
    else:
        section("Singletons", False, "  none -- every tag carries 2+ articles.")

if blocked_findings or over_cap:
    print("\nFAIL: regressions detected.", file=sys.stderr)
    sys.exit(1)

print("\nok: no regressions.")
PY
