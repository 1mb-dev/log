---
title: The Oncall
description: Solo means the deploy has your phone number.
date: "2026-05-10T10:00:00Z"
tags:
  - craft
  - ops
  - solo
  - devops
  - oncall
categories:
  - Essays
draft: false
banner: /static/img/banners/the-oncall.png
---

Solo means the deploy has your phone number.

Six months later the phone vibrates at 3am. The thing that broke is something you shipped. There is no rotation. No L2. No team on the other side of the alert. One builder. One phone. One set of eyes.

Past you didn't think about future you. Past you was in a hurry. Past you skipped the integration test because the happy path worked. Past you made the deploy fast because nothing was on fire.

Future you is on fire.

The runbook is whatever you remember. The dashboard you didn't build. The metric you didn't graph. The error you didn't catch. Every gap in observability becomes a gap in sleep.

Big teams have postmortem templates. Solo, the postmortem is a text to nobody. The lessons aren't documented because no one else needs them. They get learned and re-learned until the deploy stops biting.

The engineer hat and the ops hat are usually two people. Solo, they're the same person, six months apart. One ships fast. The other pays for it.

Builders learn ops the way cooks learn fire safety. After.

The deploy you shipped fast is the page that wakes you up.
The deploy you shipped slow is the one that didn't.
3am is when you find out which one you were.
