---
title: Test your Neovim plugins with luarocks & busted
tags: neovim, plugin, luarocks, lua, busted, test, plenary
---

<!-- markdownlint-disable -->
<br />
<div align="center">
  <a href="https://github.com/nvim-neorocks/neorocks">
    <img src="https://avatars.githubusercontent.com/u/124081866?s=400&u=0da379a468d46456477a1f68048b020cf7a99f34&v=4" alt="neorocks">
  </a>
  <h2>🌒</h>
</div>
<!-- markdownlint-restore -->

In my [previous post](https://mrcjkb.dev/posts/2023-01-10-luarocks-tag-release.html),
I wrote about some pain points in the Neovim plugin ecosystem,
and introduced the [luarocks-tag-release](https://github.com/marketplace/actions/luarocks-tag-release)
GitHub action, which allows you to publish your Neovim plugins to [LuaRocks](https://luarocks.org/),
as a call to address those pain points.

At the end, I stated that I was planning to play around with a few ideas:

> - Perhaps a package manager as a proof-of-concept?
> - Maybe a package that can use Neovim as an interpreter to run LuaRocks
>   so that it can use Neovim's Lua API in test runs?

...and I ended up going down the second rabbit hole.

## Why not just use `plenary.nvim` to test plugins?

Before Neovim 0.9, the status quo for Lua plugins has been to use [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim)
for testing.
This still seems to be the case for many (including my own plugins, as of writing this post).
Popular plugin templates still use `plenary-test` in their CI.

For example:

- [nvim-lua/nvim-lua-plugin-template](https://github.com/nvim-lua/nvim-lua-plugin-template/blob/57565ed685c1fe2d16022b2d128092becac802eb/.github/workflows/tests.yml#L26)
- [ellisonleao/nvim-plugin-template](https://github.com/ellisonleao/nvim-plugin-template/blob/29d9752/Makefile)
- [m00qek/plugin-template.nvim](https://github.com/m00qek/plugin-template.nvim/blob/704ad7b/test/Makefile)

What are the downsides of using `plenary-test`?

For one thing, it is a stripped-down re-implementation of [`busted`](https://lunarmodules.github.io/busted/).
As such, it only supports [a small subset of busted items](https://github.com/nvim-lua/plenary.nvim/blob/499e0743cf5e8075cd32af68baa3946a1c76adf1/doc/plenary-test.txt#LL55C1-L64C1).
Functions like `setup`, `teardown`, `insulate`, `expose`, `finally`,
or features like tagging tests, are not implemented.

Another downside is that different plugins have different approaches at managing the
`plenary-test` dependency. An approach I see quite often is to clone the plenary.nvim
repository into `$HOME/.local/share/nvim/site/pack/vendor/start`
and then to symlink it to the project's root or parent directory.
This is not very intuitive for potential contributors.
Plus, the fact that many plugins use `git clone` to fetch the `HEAD` of plenary.nvim's
`master` branch, is not ideal for reproducibility.

## Enter Neovim 0.9

With the introduction of Neovim 0.9, [you can now leverage the `-l` option](https://neovim.io/doc/user/starting.html#-l)
to run lua scripts via the command-line interface.
Combining this with `-c lua [...]`, Neovim transforms into a full-fledged LuaJIT interpreter,
providing access to the [Neovim lua API](https://neovim.io/doc/user/lua.html).

To test this out, you can create a `sayHello.lua` file with the following content:

```lua
vim.print { "Hello", name }
```

Then run

```console
nvim -c 'lua name = "teto"' -l sayHello.lua
> { "Hello", "teto" }
```

As it turns out, it's quite easy to run `busted` tests using Neovim 0.9+ as the interpreter.

## How to test your plugin with `busted`

### Prerequisites

- If your plugin has any dependencies, it is a lot easier to set up
  if they [are available on LuaRocks](https://luarocks.org/labels/neovim).
- So in case they aren't, open an issue asking to publish releases to LuaRocks,
  e.g. using the [luarocks-tag-release](https://github.com/marketplace/actions/luarocks-tag-release)
  GitHub action.
- Install `luarocks` using your distro's package manager
  and also install `LuaJIT` or `Lua 5.1`.
  The version doesn't matter, since we'll be using Neovim as the interpreter.
  But `luarocks` needs a real Lua installation that exposes its C header files to
  install dependencies.

### Preparing your plugin

#### 1. Add a `.rockspec` file

If your plugin has any dependencies, add a [rockspec](https://github.com/luarocks/luarocks/wiki/Rockspec-format)
named `<my-plugin>-scm-1.rockspec`[^1] to your project's root.

[^1]: Replace `<my-plugin>` with the name of your plugin.

A minimal rockspec for testing might look something like this:

```lua
rockspec_format = '3.0'
package = '<my-plugin>'
version = 'scm-1'

test_dependencies = {
  'lua >= 5.1',
  'plenary.nvim',
  'nui.nvim',
}

source = {
  url = 'git://github.com/mrcjkb/' .. package,
}

build = {
  type = 'builtin',
}
```

This file tells luarocks and `busted` how to build your plugin as a Lua package
and which dependencies to install before running tests.

#### 2. Add a `.busted` file

Next, add a `.busted` file to the root of your project, to configure `busted`.
This file should contain the following content:

```lua
return {
  _all = {
    coverage = false,
    lpath = "lua/?.lua;lua/?/init.lua",
  },
  default = {
    verbose = true,
  },
  tests = {
    verbose = true,
  },
}
```

> **Note**
>
> The `lpath` is necessary to tell `busted` to look for your plugin's source
> code in the `lua` directory.

#### 3. Add luarocks project files to `.gitignore`

Add the following to your `.gitignore`:

```sh
/luarocks
/lua_modules
/.luarocks
```

#### 4. Tell busted to use Neovim as a lua interpreter

Finally, add a `run-tests.sh` script:

<!-- markdownlint-disable -->
```sh
#!/bin/sh
BUSTED_VERSION="2.1.2-3"
luarocks init
luarocks install busted "$BUSTED_VERSION"
luarocks config --scope project lua_version 5.1
nvim -u NONE \
  -c "lua package.path='lua_modules/share/lua/5.1/?.lua;lua_modules/share/lua/5.1/?/init.lua;'..package.path;package.cpath='lua_modules/lib/lua/5.1/?.so;'..package.cpath;local k,l,_=pcall(require,'luarocks.loader') _=k and l.add_context('busted','$BUSTED_VERSION')" \
  -l "lua_modules/lib/luarocks/rocks-5.1/busted/$BUSTED_VERSION/bin/busted" "$@"
```
<!-- markdownlint-restore -->

and make it executable:

```console
chmod +x run-tests.sh
git update-index --chmod=+x run-tests.sh
```

That's it! The script uses `luarocks` to install `busted` and configures
Neovim to be able to find it using the `-c` argument.
It then runs `busted` with the `-l` argument,
and forwards any arguments you pass to the script.
The `.busted` file and the rockspec tell `busted` how to find your plugin
and its dependencies.
By passing [`-u NONE`](https://neovim.io/doc/user/starting.html),
we tell Neovim to skip loading vimrc files and plugins.

To run your tests located in a directory named `tests`, simply execute

```console
./run-tests.sh tests
```

Without any arguments, `busted` looks for `*_spec.lua` files in
a directory named `spec`.


## Using GitHub Actions to run tests

So far, this post has discussed using `busted` locally for testing Neovim plugins.
However, to ensure thorough testing, compatibility, and bug detection across different environments,
it's essential to make this approach compatible with CI workflows like GitHub Actions.

Starting from version 5.0, the `luarocks-tag-release` GitHub action will automatically
run tests if it detects a `.busted` file in the project root.
By default, it will execute [`luarocks test`](https://github.com/luarocks/luarocks/wiki/test)
with both the stable Neovim release and Neovim nightly as the Lua interpreter[^2],
before publishing the plugin to LuaRocks.
You can configure the action to run not only on tags, but also on pull requests (without
publishing to LuaRocks.org).

[^2]: `luarocks-tag-release` updates the Neovim interpreters weekly.

> **Note**
>
> `luarocks-tag-release` uses [`neorocks`](https://github.com/nvim-neorocks/neorocks),
> a (slightly over-engineered) `luarocks` [nix](https://nixos.org/) derivation
> configured to use Neovim's Lua interpreter, to run the tests.

If you prefer not to publish your plugins to LuaRocks,
I'll leave the exciting exercise of crafting a custom GitHub Action
as a challenge for you! 😈

## Moving forward

If this has motivated you to try out using `luarocks` and `busted` to test your Neovim plugins,
I'd love to [hear your feedback](https://github.com/nvim-neorocks/luarocks-tag-release/discussions/categories/feedback)!

- Have you run into any issues?
- Is there still something Neovim-specific that `plenary-test` provides,
  which you are missing from this approach?
- Do you have any other thoughts?

Personally, I would like to see LuaRocks being able to run using Neovim,
without having to install Lua.
This possibility doesn't seem far-fetched, especially considering that
[there are other communities that would also benefit from such an integration](https://github.com/luarocks/luarocks/issues/1499#issuecomment-1492486727).
