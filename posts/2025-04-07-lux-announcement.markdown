---
title: Announcing Lux - a luxurious package manager for Lua
tags: lua, luarocks, neovim, nix
class: container
---

![](https://github.com/nvim-neorocks/lux/raw/master/lux-logo.svg){ width=300px }

It's time Lua got the ecosystem it deserves!

For a bit over a year, we have been cooking up [Lux](https://github.com/nvim-neorocks/lux),
a new package manager for creating, maintaining and publishing Lua code.
It does this through a simple and intuitive CLI inspired by other
well-known package managers like [`cargo`](https://doc.rust-lang.org/cargo/).

Today, we feel the project has hit a state of "very usable for everyday tasks"[^1].

[^1]: We still have things to flesh out, like MSVC support, error messages and edge cases,
      but all those fixes are planned for the 1.0 release.


## Features

- Fully portable between systems.
- Parallel builds and installs. 🚀
- Handles the installation of Lua headers[^2] for you.
  Forget about users complaining they have the wrong Lua headers installed on their system.
  All you need to do is specify compatible lua versions.
- A fully embeddable `lux-lib` crate, which can even be built to expose a Lua API.
- Has an actual notion of a "project", with a simple governing `lux.toml` file.
  - Uses the `lux.toml` to auto-generate rockspecs.
    Say goodbye to managing 10 different rockspec files in your repository. 🎉
- Powerful lockfile support.
  - Fully reproducible builds and developer environments.
  - Source + rockspec hashes that can be used to make Lux easy to integrate with [Nix](https://nixos.org/).
- Integrated code formatting (`lx fmt`) and linting (`lx check`)
  powered by [`stylua`](https://github.com/JohnnyMorganz/StyLua)
  and [`luacheck`](https://github.com/mpeterv/luacheck).
- Native support for running tests with [`busted`](https://lunarmodules.github.io/busted/).
  - Including the ability to use Neovim as a Lua interpreter.
  - Sets up a pure environment.
- Compatible with the luarocks ecosystem.
  - In case you have a complex rockspec that you don't want to rewrite to TOML,
    lux allows you to create an `extra.rockspec` file, so everything just works.
  - Need to install a package that uses a custom luarocks build backend?
    Lux can install luarocks and shell out to it for the build step,
    while managing dependencies natively.

[^2]: Lua 5.1, 5.2, 5.3. 5.4 and luajit.


## Motivation

### Lua

While extensive, Luarocks carries with it around 20 years of baggage,
which makes it difficult to make suitable for modern Lua development, while
retaining backward compatibility.

With Lux, we're pushing for a fresh start:

- **A notion of a project:**
  - With TOML as the main manifest format, you can easily add, remove, pin
    and update dependencies using the CLI.
  - If you're in a project directory (with a `lux.toml`), commands like `build`
    will build your project, and install it into a project-local tree.
  - Building will produce a lockfile of your project's dependencies,
    allowing you to reproduce your exact dependencies on any compatible system.
- **Enforced SemVer:**
  Luarocks allows for arbitrary versions after the patch version.
  For example, `1.0.1.0.0.0.2` is considered valid by Luarocks, but it has no
  useful meaning.
  Lux will parse this too, but will treat everything after the patch
  version as a prerelease version.
  We made this decision because we want to encourage package maintainers
  to stick to [SemVer](https://semver.org/) for their releases.
- **Parallel builds:**
  Inspired by the Nix store, Lux hashes[^3] install directories to prevent
  package conflicts and enable highly parallel builds without risking file system corruption.

[^3]: See [our guide](https://nvim-neorocks.github.io/explanations/lux-package-conflicts)
      for details.

### Neovim

Thanks to our Neovim plugin manager, [`rocks.nvim`](https://github.com/nvim-neorocks/rocks.nvim),
and the later addition of Luarocks support to [`lazy.nvim`](https://github.com/folke/lazy.nvim),
Luarocks has been steadily gaining popularity in the Neovim space as a way of distributing
plugins.
But it's been heavily held back by not being fully portable and by being unpredictable
from system to system.
Because Luarocks is written in Lua, installing a large number of packages
and synchronising plugins with `rocks.nvim` has been painfully slow.

With Lux, we hope that plugins will start treating themselves as Lua projects.
Using Lux is non-destructive and doesn't interfere with the current way of
distributing Neovim plugins (which is via git).

In fact, Lux has a `--nvim` flag, which tells it to install packages into a tree
structure that is compatible with Neovim's [`:h packages`](https://neovim.io/doc/user/repeat.html#packages).

### Nix

If a Neovim plugin exists as a Luarocks package, [`nixpkgs`](https://github.com/NixOS/nixpkgs)
will use it as the source of truth.
This is mainly because with a proper package manager, the responsibility of declaring dependencies
is the responsibility of the package author.
However, Luarocks has very basic lockfile support, which does not include source hashes.
While Luarocks (as does Lux) supports conflicting dependencies
via its [`luarocks.loader`](https://luarocks.org/modules/hisham/luarocks-loader),
nixpkgs cannot reasonably add multiple versions of the same dependency to its package set.
Lux's [`lux.lock`](https://github.com/nvim-neorocks/lux/blob/5d2bee87a99afb6e532421d381d1b4986b855d56/lux-lib/resources/test/sample-project-lockfile-missing-deps/lux.lock),
stores source and rockspec hashes of each dependency.
If the source URL is a git repository, lux will store a [NAR hash](https://nix.dev/manual/nix/2.26/store/file-system-object/content-address#serial-nix-archive).
This means the a `lux.lock` can be used to create a [`fixed-output derivation`](https://bmcgee.ie/posts/2023/02/nix-what-are-fixed-output-derivations-and-why-use-them/)
with all dependencies, just as you can do with a `Cargo.lock`.


## Next steps

Right now, our priorities are set on squashing bugs and improving error messages.
Soon, we'll be rewriting `rocks.nvim` to use Lux instead of Luarocks under the hood.
This should let rocks.nvim catch up with other plugin managers in terms of speed
and make it endlessly more stable than before.
If the rewrite is successful, then that spells great news for the Neovim ecosystem
going forward, as it means that Lux can be embedded in other places too
(e.g. lazy.nvim, which has had troubles with luarocks in the past)!


## Documentation

If you'd like to jump on the Lux train early, head over to [our documentation website](https://nvim-neorocks.github.io/tutorial/getting-started).
A tutorial as well as guides can be found on there.

If you have any questions or issues, feel free to reach out in [the GitHub discussions](https://github.com/nvim-neorocks/lux/discussions)
or [our issue tracker](https://github.com/nvim-neorocks/lux/issues). Cheers! :)

The Lux Team
