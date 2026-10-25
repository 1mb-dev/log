---
title: Terms You Can't Pin
description: "The dependency that never reaches the lockfile, and the day a solo builder turns out to be one."
date: "2026-10-25T10:00:00Z"
tags:
  - dependencies
  - solo
  - reality
categories:
  - Essays
draft: false
banner: /static/img/banners/terms-you-cant-pin.png
---

Pricing update, effective in thirty days.

Six words in a subject line. Somewhere, a side project just gained a line in its budget.

Nothing in the code changed. The build is green. The project depends on something that was never in the lockfile.

A library can be pinned. Version 4.2.1, forever, if that's what it takes. A hosted API can't. Neither can a free tier or a terms of service. They live on someone else's roadmap.

Free was never a gift. It was a price, set to zero for now. "For now" was in the terms all along. Nobody reads that part while the number is zero.

So the dependency grew where no tool could see it. A webhook here. An email API there. A hosted database, because it was free and the project was small. A login provider, because rolling one felt like a week. Each choice was reasonable on the day it was made. None of them showed up in an audit.

The new price is rarely the real cost. A bill can be paid. A deprecated endpoint can be replaced. The cost is the afternoon spent finding out how much was standing on it. One email, and the architecture review nobody scheduled starts that morning.

On the other end, someone has servers to pay for and a board asking about margins. A free tier ending is a business doing arithmetic. Solo builders know that arithmetic. They run it on their own projects every month.

The small API a solo builder hosts is a platform to someone. So is the library with the generous license, and the free tool with a few hundred users. A stranger wired it into their project because it was free, and it worked, and it was there.

The arithmetic comes due on that side too.

One builder's infrastructure is another builder's dependency.
Most end up on both sides of that email.
