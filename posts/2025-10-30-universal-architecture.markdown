---
title: Universal architecture - A Haskell-inspired approach to OOP
tags: haskell, OOP, architecture, IO, tests
class: container
---

While in the sauna at [CodeFreeze](https://codefreeze.fi/) 2024,
my friend [Pablo](https://pablo.codes/) started talking to me about the "universal architecture",
based on [a podcast featuring J.B. Rainsberger](https://fullstackradio.com/38).

## Separating business logic and IO

As a Haskell developer, the ideas resonated with me.
My favourite (and often misunderstood) feature of Haskell is the strict separation
between pure business logic and IO.
This encourages splitting a program into an IO part and a pure part.
For example, an application that processes stock quotes might be split as follows[^1]:

IO part:

- Read quotes from an input file
- Print report
- Generate images (charts)
- Save report

Pure part:

- Parse input data
- Compute statistics
- Describe charts
- Format report

[^1]: Example from the book, ["Haskell in Depth"](https://www.manning.com/books/haskell-in-depth).

The `main` program interleaves the IO and pure parts using monadic composition[^2],
producing the running application.

[^2]: Haskell's way of sequencing effectful computations.

So why is this my favourite feature of Haskell? One word: testability. Pure code is deterministic
and easy to test in isolation. Tests can run entirely in memory.
If you want continuous integration, you should [agree as a team never to break the build](https://thinkinglabs.io/articles/2022/09/17/the-practices-that-make-continuous-integration-team-working.html#practice-2-agree-as-a-team-to-never-break-the-build).
To support that, we should avoid IO bottlenecks in our pipelines.

## Test tiers for separated IO and business logic

Separating business logic and IO lets you split your test suite into two focused tiers:

- Integration / acceptance tests:
  Verify assumptions about external IO ports (files, databases, APIs, third‑party libraries, ...)
  These tests exercise the real integrations and can be slow or brittle;
  with a clear separation they only need to run when the ports or their contracts change
  (for example, when upgrading a dependency or changing an API).
- Property / behavioural (pure) tests:
  Verify the properties and behaviour of your pure business logic.
  Because these tests run entirely in memory and have no side effects,
  they are fast and deterministic, making them ideal for running frequently,
  for example in a [pre-push hook](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks).

## Interfaces as boundaries: separating what you control from what you don't

Recently, I attended a [SoCraTes day](https://socrates-day.ch/) session,
in which a group of OOP developers discussed hexagonal/clean architecture.
At some point, someone asked, "what is even the use of interfaces"?
The room agreed that interfaces are pointless unless you have three or more implementations.
That's a common but misleading belief.

As Alexander Granin points out,
"this statement misses the point of interfaces and their purpose"[^3].

[^3]: In his great book, ["Functional Design and Architecture"](https://www.manning.com/books/functional-design-and-architecture).

The point of interfaces is not to abstract over multiple implementations;
it is to decouple the business logic you control from the external world you do not control.
