---
title: Example Article
description: Replace this file with your own writing. It exists to show markgo's expected frontmatter.
slug: example-article
date: 2026-05-15T10:00:00Z
tags: [example, scaffold]
categories: [Essays]
draft: true
author: Your Name
---

This file documents markgo's frontmatter shape. `draft: true` keeps it out of public feeds; delete the file (or flip the flag) once you start writing.

## Frontmatter fields

- `title` -- shown in feeds, page titles, OG cards.
- `description` -- meta description, RSS summary.
- `slug` -- URL path. Defaults to the filename if omitted.
- `date` -- RFC 3339. Controls feed ordering.
- `tags` -- flat list, surfaced in feeds and filter pills.
- `categories` -- `Essays`, `Thoughts`, `Links`, `AMA`. See markgo's `docs/design.md` for what each implies.
- `draft` -- `true` hides from public feeds.
- `author` -- per-article override of `BLOG_AUTHOR` from `.env`.

Filenames following `YYYY-MM-DD-thought-*.md` are inferred as thoughts when `categories` is omitted; explicit frontmatter always wins.

## Writing

Standard CommonMark. Fenced code blocks pick up syntax highlighting:

```go
fmt.Println("hello")
```

Lists, quotes, images, and links behave the way markdown expects.

When this file no longer serves you, `rm articles/_example.md`.
