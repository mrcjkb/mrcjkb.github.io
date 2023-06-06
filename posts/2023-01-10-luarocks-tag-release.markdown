---
title: Publish your Neovim plugins to LuaRocks
tags: neovim, plugin, luarocks, lua, dependencies
---

This is a follow-up on a [series of blog posts](https://teto.github.io/posts/2021-09-17-neovim-plugin-luarocks.html) by @teto that propose a solution to a major pain point of the Neovim plugin ecosystem - Dependency management.

As someone who only recently started maintaining Neovim plugins, I have been quite frustrated with my experience so far...

## The current status quo


### 1. A horrible UX

...where users, not plugin authors, have to declare dependencies.

[Here's](https://github.com/junnplus/lsp-setup.nvim#packernvim) an example using `packer.nvim`:

```lua
use {
  'junnplus/lsp-setup.nvim',
  requires = {
    'neovim/nvim-lspconfig',
    'williamboman/mason.nvim',
    'williamboman/mason-lspconfig.nvim',
  }
}
```

This shouldn't be the user's responsibility.

What if dependencies are added or changed? It's the user who has to update their config or deal with breakage.


### 2. Plugin authors copy/pasting code instead of using libraries

...because they don't want their users to have to deal with this horrible UX.

I've been guilty of doing so myself.


### 3. Instability

As far as I know, we currently have no easy way to declare version constraints for dependencies.
Something that [LuaRocks](https://luarocks.org/) supports, and which definitely should not be left up to the user.

All of this potentially gets worse with transitive dependencies.


## The vicious cycle

As I see it, we have ourselves a dilemma:

* Neovim plugin authors don't use LuaRocks because plugin managers don't support it.
* Plugin managers don't support LuaRocks properly [because there aren't enough plugins that use it](https://github.com/folke/lazy.nvim/issues/253#issuecomment-1411534276).

This is something I've observed in many fields.
For example, critics of electromobility have claimed that EVs will never be feasible, because we don't have enough charging infrastructure.
But which came first? Cars, or petrol stations?

I'm a strong believer that we need plugin authors to publish their packages to LuaRocks before package managers start supporting it.
Just like we had cars before petrol stations, and electric vehicles before charging infrastructure.


## Introducing the [LuaRocks tag release action](https://github.com/marketplace/actions/luarocks-tag-release)

As a catalyst to alleviate these issues, @teto and I have started the [`nvim-neorocks`](https://github.com/nvim-neorocks/) organisation and released the [`luarocks-tag-release`](https://github.com/marketplace/actions/luarocks-tag-release) GitHub action.

The goal is to minimise the effort for developers to release their plugins to LuaRocks,
and to keep their published packages up to date.


### How to get started as a plugin developer?

* All you need is a [LuaRocks account](https://luarocks.org/login) and an [API key](https://luarocks.org/settings/api-keys).
* Add the API key to your repo's [GitHub actions secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository).
* Finally, create a `.github/workflows/release.yml` in your repository that uses the `luarocks-tag-release` action:

```yaml
name: LuaRocks release
on:
  push:
    tags:
      - "*"

jobs:
  luarocks-release:
    runs-on: ubuntu-latest
    name: LuaRocks upload
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: LuaRocks Upload
        uses: nvim-neorocks/luarocks-tag-release@v4
        env:
          LUAROCKS_API_KEY: ${{ secrets.LUAROCKS_API_KEY }}
        with: # Optional inputs...
          dependencies: |
            plenary.nvim
            nvim-lspconfig
```

Whenever you push a tag (expected to adhere to [semantic versioning](https://semver.org/)),
the workflow will:

1. Automatically fetch most of the relevant information (summary, license, ...) from GitHub
2. Generate a rockspec for the release
3. Run a test to make sure LuaRocks can install your plugin locally
4. Publish your plugin to LuaRocks
5. Run a test to verify that your plugin can be installed from LuaRocks

If you need more flexibility, you can [specify additional inputs](https://github.com/marketplace/actions/luarocks-tag-release#inputs) or even use a [rockspec template](https://github.com/marketplace/actions/luarocks-tag-release#template).

To advertise that your plugin is available on LuaRocks, you can add a shield to your README:

```markdown
[![LuaRocks](https://img.shields.io/luarocks/v/<user>/<plugin>?logo=lua&color=purple)](https://luarocks.org/modules/<user>/<plugin>)
```

For example:

[![LuaRocks](https://img.shields.io/luarocks/v/neovim/nvim-lspconfig?logo=lua&color=purple)](https://luarocks.org/modules/neovim/nvim-lspconfig)
```markdown
[![LuaRocks](https://img.shields.io/luarocks/v/neovim/nvim-lspconfig?logo=lua&color=purple)](https://luarocks.org/modules/neovim/nvim-lspconfig)
```

Here are some workflows and PRs you can use for inspiration:

* [`nvim-lspconfig`](https://github.com/neovim/nvim-lspconfig/blob/master/.github/workflows/release.yml)
* [`haskell-tools.nvim`](https://github.com/mrcjkb/haskell-tools.nvim/blob/master/.github/workflows/release.yml)
* [`telescope-manix`](https://github.com/mrcjkb/telescope-manix/blob/master/.github/workflows/release.yml) - an extension that depends on [`telescope.nvim`](https://github.com/nvim-telescope/telescope.nvim/pull/2364)[^1].
* [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter/pull/4109)[^1] - A more complex example that uses a template to build with Make.
* [`plenary.nvim`](https://github.com/nvim-lua/plenary.nvim/pull/458/files)[^1] - Another example that uses a template so that LuaRocks runs tests.
* [`fzf-lua`](https://github.com/ibhagwan/fzf-lua/blob/main/.github/workflows/luarocks-release.yaml) - A scheduled workflow that realeases versions based on the number of commits, if there have been new commits since the last run.

[^1] pull request

See also [the workflow's wiki page](https://github.com/nvim-neorocks/luarocks-tag-release/wiki/Example-configurations).


### What can you do as a Neovim user?

If you don't maintain your own plugins, but want to see the ecosystem improve, you can suggest the workflow to your favourite plugins, or open a pull request.
In most cases, it's extremely easy to add the workflow. See the above PR examples.

If you run in to problems or have any questions, don't hesitate to [open an issue](https://github.com/nvim-neorocks/luarocks-tag-release/issues) or [start a discussion](https://github.com/nvim-neorocks/luarocks-tag-release/discussions)!


### What's next?

For now, I am experimenting with a fork of LuaRocks, stripped down to the bare minimum needed to install packages.
I am still uncertain of what that will lead to in the near future.

* Perhaps a package manager as a proof-of-concept?
* Maybe a package that can use Neovim as an interpreter to run LuaRocks so that it can use Neovim's Lua API in test runs?

Hopeful for the future. Let's make this happen!

### Follow-up

[Test your Neovim plugins with luarocks & busted](https://mrcjkb.dev/posts/2023-06-06-luarocks-tag-release.html)
