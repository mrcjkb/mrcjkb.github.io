---
title: Test your Neovim plugins with luarocks and busted
tags: neovim, plugin, luarocks, lua, busted, test, plenary
class: container
---

<!-- markdownlint-disable -->
<br />
<div align="center">
  <a href="https://github.com/nvim-neorocks/nvim-busted-action">
    <img src="https://avatars.githubusercontent.com/u/124081866?s=400&u=0da379a468d46456477a1f68048b020cf7a99f34&v=4" alt="nvim-busted-action">
  </a>
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

- [ellisonleao/nvim-plugin-template](https://github.com/ellisonleao/nvim-plugin-template/blob/29d9752/Makefile)
- [m00qek/plugin-template.nvim](https://github.com/m00qek/plugin-template.nvim/blob/704ad7b/test/Makefile)
- [nvim-lua/nvim-lua-plugin-template](https://github.com/nvim-lua/nvim-lua-plugin-template/blob/57565ed685c1fe2d16022b2d128092becac802eb/.github/workflows/tests.yml#L26) (Now uses `busted`)

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
  install certain dependencies.

### Preparing your plugin

#### 1. Add a `.rockspec` file

Add a [rockspec](https://github.com/luarocks/luarocks/wiki/Rockspec-format)
named `<my-plugin>-scm-1.rockspec`[^1] to your project's root.

[^1]: Replace `<my-plugin>` with the name of your plugin.

A minimal rockspec for testing might look something like this:

```lua
rockspec_format = '3.0'
package = '<my-plugin>'
version = 'scm-1'

test_dependencies = {
  'lua >= 5.1',
  'nlua',
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
    lua = "nlua",
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
> - The `lpath` is necessary to tell `busted` to look for your plugin's source
>   code in the `lua` directory.
> - `lua = "nlua"` runs your tests with [`nlua`](https://github.com/mfussenegger/nlua)
>   (a Neovim-Lua CLI adapter) as the Lua interpreter.

#### 3. Run your tests

That's it! You can run your tests with

```bash
luarocks test --local
# or
busted
```

Without any arguments, `busted` looks for `*_spec.lua` files in
a directory named `spec`.

Or if you want to run a single test file:

```bash
luarocks test spec/path_to_file.lua --local
# or
busted spec/path_to_file.lua
```

## Using GitHub Actions to run tests

So far, this post has discussed using `busted` locally for testing Neovim plugins.
However, to ensure thorough testing, compatibility, and bug detection across different environments,
it's essential to make this approach compatible with CI workflows like GitHub Actions.

For that, you can use the [nvim-busted-action](https://github.com/nvim-neorocks/nvim-busted-action),
which will take care of all the setup for you.

## Moving forward

If this has motivated you to try out using `luarocks` and `busted` to test your Neovim plugins,
I'd love to [hear your feedback](https://github.com/nvim-neorocks/nvim-busted-action/discussions/categories/ideas)!

- Have you run into any issues?
- Is there still something Neovim-specific that `plenary-test` provides,
  which you are missing from this approach?
- Do you have any other thoughts?

Personally, I would like to see LuaRocks being able to run using Neovim,
without having to install Lua.
This possibility doesn't seem far-fetched, especially considering that
[there are other communities that would also benefit from such an integration](https://github.com/luarocks/luarocks/issues/1499#issuecomment-1492486727).

> **Note**
>
> This post has been updated to use [`nlua`](https://github.com/mfussenegger/nlua),
> instead of creating a busted wrapper script manually.
