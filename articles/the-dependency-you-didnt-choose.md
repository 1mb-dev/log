---
title: A Lockfile Is a List of People
description: The unseen maintainers behind transitive dependencies no one chose.
date: "2026-06-26T10:00:00Z"
tags:
  - dependencies
  - open-source
  - solo
  - philosophy
categories:
  - Essays
draft: false
banner: /static/img/banners/the-dependency-you-didnt-choose.png
---

A lockfile. Thousands of lines. Each one a dependency.

Most of them were not chosen.

One library was picked deliberately. The docs were clear. The API made sense. The README did what it said it would. That one library pulled in fourteen others.

One handles date formatting. One parses command-line flags. One wraps a filesystem operation the standard library already does, slightly differently. No one read their source. No one visited their repositories. The name on the package is all anyone knows.

One of those fourteen is maintained by a person in a timezone the project has never been in.

They ship from a laptop that could die tomorrow. They fix bugs on weekends. They merged a security patch at eleven at night, their time, and nobody thanked them. The commit was a single line. It kept the project running.

No one noticed.

The chain is longer than it looks, and the trust is implicit. No verification gate. It held because it held yesterday. The dependency graph is not a technical architecture. It is a social one. People, not packages.

One of them stops tomorrow. No announcement. No sunset post. Just silence. The repo stays up. The last release was six months ago. Issues pile up. Someone forks it. Someone else doesn't. The chain does not break loudly. It degrades quietly, a link at a time. The first sign is a build that fails for a reason no one understands.

The audit tools exist. The scanners run. The CVEs get filed. This is not another one of those.

This is noticing what the tools do not see. Behind every line in the lockfile is a person who did not ask for a stranger's project to depend on them. They wrote a thing that solved their problem. The project inherited them. One-way. Load-bearing.

The toolchain reports vulnerabilities.
It does not report the person who might stop tomorrow.
