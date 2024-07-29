---
title: A modern approach to tree-sitter parsers in Neovim
tags: neovim, tree-sitter, plugin, dependencies, luarocks
class: container
---

One and a half years ago, I published [a post](https://mrcjkb.dev/posts/2023-01-10-luarocks-tag-release.html)
with a call to action to publish Neovim plugins to luarocks.
Since then, a lot has happened.

The [nvim-neorocks](https://github.com/nvim-neorocks) organisation has grown
and produced [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim), which pioneers
luarocks support in Neovim, treating luarocks packages as first-class citizens.
A lot of plugins are now available on luarocks.org, and publishing plugins that aren't
yet available [has never been easier](https://github.com/nvim-neorocks/rocks.nvim/wiki/Plugin-support).

I'd like to take some time to provide an update on some recent developments...

## The path to nvim-treesitter 1.0

One of my favourite things about Neovim is how easy it is to do exceptionally cool things with
[tree-sitter](https://tree-sitter.github.io/tree-sitter/).
For those new to the concept, tree-sitter is a parsing library that can be used to provide
fast and accurate syntax highlighting, code navigation, and much more.

My [very first Neovim plugin](https://github.com/mrcjkb/neotest-haskell) was
a Haskell adapter for [neotest](https://github.com/nvim-neotest/neotest), which uses
tree-sitter queries to interact with test suites within Neovim, providing diagnostics
for tests, among other things.

However, even though [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
has been around [since early 2020](https://github.com/nvim-treesitter/nvim-treesitter/graphs/code-frequency),
as of writing this post, its readme still has the following notice:

> **Warning: Treesitter and nvim-treesitter highlighting are an experimental feature of Neovim.
> Please consider the experience with this plug-in as experimental until Tree-Sitter support in Neovim is stable!**

### A roadmap to stability

Over the past year, development has accelerated, and there now exists
[a roadmap for a stable version 1.0](https://github.com/nvim-treesitter/nvim-treesitter/issues/4767).

The plugin is being rewritten[^1] to completely drop the module framework.

[^1]: As of writing, the nvim-treesitter 1.0 roadmap is subject to change.

Instead, it will only manage parser and query installations.
This means that when you install nvim-treesitter 1.0, you won't have any queries on the runtimepath
unless you install a matching parser.
Many plugins that used to depend on the legacy module system are now standalone plugins,
requiring only the parsers.

### Practical example

Typically, a plugin that depends on a tree-sitter parser will indicate its dependency on
nvim-treesitter in its documentation.
For instance, here are [the lazy.nvim install instructions](https://github.com/MeanderingProgrammer/markdown.nvim/tree/35f8bd24809e21219c66e2a58f1b9f5d547cc2c3?tab=readme-ov-file#lazynvim)
for markdown.nvim:

```lua
{
    'MeanderingProgrammer/markdown.nvim',
    main = "render-markdown",
    opts = {},
    name = 'render-markdown', -- Only needed if you have another plugin named markdown.nvim
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
}
```

Interestingly, this plugin doesn't actually depend on nvim-treesitter.
Did you know that you don't even need nvim-treesitter to install parsers?

## A quick dive into `:TSInstall`

Let's take a look at how nvim-treesitter manages parsers and queries.
On the `master` branch, which still has the legacy module system, queries for basic
functionality, such as highlights (+ injections), folds, indents, are present on the runtimepath,
in nvim-treesitter's `queries/<lang>`[^2] directory.

[^2]: `<lang>` is the name of the matching parser.

As mentioned earlier, this will change with version 1.0 (and you can test-drive it today
with Neovim nightly on the `main` branch).
Queries will be in a `runtime/queries` directory, so they won't be added to the runtimepath
until you install the parser.
The plugin locks compatible parser revisions in a [`lockfile.json`](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/lockfile.json).
And the nvim-treesitter CI only updates a parser's revision if the automated tests
for the matching queries don't break.
This minimises the risk that queries stop working when you update nvim-treesitter and the
installed parsers.
Of course, the effectiveness for any given parser depends on how well its queries are tested.

When installing a parser, nvim-treesitter delegates to [`tree-sitter-cli`](https://github.com/tree-sitter/tree-sitter/blob/master/cli/README.md),
which may in turn delegate to a C compiler.
Some parsers need to be generated from a `grammar.js` file, which requires Node.js.

With much of the heavy lifting having recently been moved from nvim-treesitter to
`tree-sitter-cli`, installing parsers has become a lot less error-prone.

However, setting up the correct toolchain [can still be a PITA on some platforms](https://github.com/nvim-treesitter/nvim-treesitter/wiki/Windows-support).

And there's one pain point that cannot be solved by keeping track of compatible parsers
in a lockfile...

## Challenges with downstream plugin compatibility

In March 2024, the tree-sitter-haskell parser underwent a complete rewrite.
This significant update brought many improvements
but also broke compatibility with several downstream plugins, including:

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/pull/6580)
- [neotest-haskell](https://github.com/mrcjkb/neotest-haskell/pull/162)
- [haskell-snippets.nvim](https://github.com/mrcjkb/haskell-snippets.nvim/pull/27)
- [vim-matchup](https://github.com/andymass/vim-matchup/pull/349)
- [iswap.nvim](https://github.com/mizlan/iswap.nvim/pull/89)
- [rainbow-delimiters.nvim](https://gitlab.com/HiPhish/rainbow-delimiters.nvim/-/commit/a0e715996c93187290c00d494d58e11d5f5e43ad)
- [haskell-scope-highlighting.nvim](https://github.com/kiyoon/haskell-scope-highlighting.nvim/pull/3)
- [nvim-treesitter-context](https://github.com/nvim-treesitter/nvim-treesitter-context/pull/447)
- [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects/pull/613)
- [tailwind-sorter.nvim](https://github.com/laytan/tailwind-sorter.nvim/pull/104)

Synchronizing updates across all these plugins to ensure a seamless transition for users
is nearly impossible, especially given the limited number of maintainers for these queries.

### Immediate impact on users

Until all downstream plugins have been updated, affected users are left with two primary options:

- **Pinning nvim-treesitter:**
  Users can pin nvim-treesitter to a version or revision that installs the old version of the parser.
  Unfortunately, this workaround means they cannot benefit from any other parser updates or fixes.
  Consequently, users may have to pin plugins that depend on other parsers,
  delaying overall ecosystem improvements.
- **Disabling plugins:**
  This approach ensures users can still receive updates for other parts of their setup
  but at the cost of losing functionality provided by the disabled plugins.

Wouldn't it be neat if you could pin parsers individually?

## Enter rocks.nvim

For a while, we (the nvim-neorocks team) have been using
[the Neovim User Rock Repository (NURR)](https://github.com/nvim-neorocks/nurr) to
automatically package many Neovim plugins for [luarocks](https://luarocks.org),
to be used with rocks.nvim.

Aside from workflows that publish Neovim plugins, we've also added a workflow that
publishes tree-sitter parsers, bundled with the matching nvim-treesitter queries, to luarocks.org.
To top it off, our [rocks-binaries](https://nvim-neorocks.github.io/rocks-binaries/)
project periodically pre-builds the parsers on Linux, macOS (x86_64 + aarch64) and Windows,
so that rocks.nvim users on those platforms don't have to worry
about installing any additional toolchains.

Recently, we've started publishing the parsers to the root manifest with `0.0.x` versions[^3],
where `x` increments every time the revision changes in the nvim-treesitter lockfile, or
whenever the parser's queries are modified[^4].

[^3]: We don't know yet if/how nvim-treesitter will handle parser versioning if/when it
      goes stable. `0.0.x` seems like a safe bet.
[^4]: Checked using the git log every 12 hours.

With luarocks packages as first-class citizens in Neovim,
this allows plugin authors to add parsers as dependencies to their luarocks packages
and has a neat side effect: rocks.nvim users can now pin each parser individually.

Welcome to a new era of flexibility and stability!

> **IMPORTANT**
>
> If you use rocks.nvim and run into issues with tree-sitter parsers,
> please bug us, not the nvim-treesitter maintainers!
> We provide a [rocks-treesitter.nvim](https://github.com/nvim-neorocks/rocks-treesitter.nvim)
> module for highlighting and auto-installing parsers, as well
> as a [nvim-treesitter-legacy-api](https://luarocks.org/modules/neorocks/nvim-treesitter-legacy-api)
> rock that provides the module systems for plugins that still depend on it,
> without adding queries that could be out-of-sync with the luarocks parsers to the runtimepath.

> **Note for plugin authors**
>
> While luarocks supports loading multiple versions
> of the same lua dependency, this does not translate
> to tree-sitter parsers.
> Neovim will use the first parser it finds on the runtimepath.
> For this reason, we currently don't recommend that plugin authors
> pin parser dependencies. You should leave that up to your users for now.
