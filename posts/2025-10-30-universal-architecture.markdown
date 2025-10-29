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

## Making GitHub Actions testable: a Universal Architecture approach

One of my favourite side projects these days is [Lux](https://mrcjkb.dev/posts/2025-04-07-lux-announcement.html),
a modern package manager for the Lua ecosystem.
A few days ago, I started working on [a GitHub action](https://github.com/marketplace/actions/luxaction)
that lets you install Lux for use in CI.

I've written some GitHub actions before and the experience was always painful.
To test your action locally, you have two options:

- Create a [composite action](https://docs.github.com/en/actions/tutorials/create-actions/create-a-composite-action)
  that uses [Nix](https://nixos.org/).
- Use [`nektos/act`](https://nektosact.com/).

The first option, using Nix, works great from a developer's perspective.
But your end-users will end up with slow workflows, because GitHub doesn't have first-class support
for Nix.

The latter option involves downloading over 20 GB of Docker images, and it only gives you
[repeatability](https://www.youtube.com/watch?v=0uixRE8xlbY), not reproducibility.

I found myself working in an object-oriented world and missing Haskell's purity.
Then I remembered Pablo's sauna session...

### Requirements

The GitHub action has to perform the following tasks:

IO part:

- Read GitHub Action inputs
- Read environment
  - Operating system (Linux, macOS, Windows)
  - Architecture (aarch64, x86_64)
  - Setting/Getting environment variables
- Logging
- Use the GitHub releases API to fetch Lux release info
- Download installer assets
- Install Lux
  - Filesystem IO
  - Execute installer artifacts
- Save/restore GitHub Actions caches

Pure part:

- Parse inputs
- Map GitHub release response to internal domain model
- Determine which release artifacts to fetch
- Compute and verify installer artifact digest (sha256 checksum)

### Architecture


