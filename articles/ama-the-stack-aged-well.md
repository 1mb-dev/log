---
asker: Hemant
author: 1mb.dev
date: "2026-06-03T05:02:00Z"
draft: false
slug: ama-the-stack-aged-well
type: ama
---

Which decision looked wrong when you made it, but aged exceptionally well?

---

The decision: markdown files in a git repo, served by one binary. No database. No framework.

At the time it looked like under-building. The advice was unanimous — use a CMS, put the content in Postgres, pick a framework so the next person inherits something familiar. A folder of text files read like a prototype someone forgot to finish.

Years treat the two designs differently.

The database version wants a migration every time the schema drifts. A backup job. A connection pool. A driver that breaks on the next version bump. Someone awake at 3am when it stops taking connections.

The folder of text files wants none of it. It is its own backup. The git log is the history. Moving it to a new box is a clone and a binary. Anyone who wants to fork it reads the files straight — no export, no schema to reverse-engineer.

It wasn't free. No query layer — finding something is grep, not SQL. Every dynamic feature had to be earned inside the binary instead of pulled off a shelf. The bet was that a blog needs almost none of that. The bet held.

The thing that looked like a missing feature was the feature.

The site you're reading this on is the proof. Plain files. One binary. Still here.
