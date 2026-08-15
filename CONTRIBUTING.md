# Working on scribe_tools

This repository is private and stays private. The source here is proprietary,
covered by the [LICENSE](LICENSE) at the root, and it is never distributed.

What leaves this repository is binaries, and only two of them.

## The three tools

| | What it is | Ships to projects |
| --- | --- | --- |
| `scribe/` | the CLI a project built on scribe runs: init, config, code generation, extensions, tests | yes |
| `docs/` | the OpenAPI route walker, called as a subprocess by `scribe` | yes |
| `sdk/` | the CLI the framework itself uses: install, deploy, keys, migrations, backup, gen proto | **no** |

`sdk` never reaches a project. It is compiled for the three platforms like the
others, and its binaries stay on the workflow run, which only people with access
to this repository can reach. Anyone working on the framework already has this
repository, so they can run it from source.

## The branches

Push to `dev`. There is no third branch: a ruleset refuses the creation of any
branch other than `dev` and `main`. Nobody pushes to `main` at all.

`main` moves when someone runs the **release** workflow by hand. It opens the
pull request from `dev`, and merging it is what compiles the tools and pushes
`scribe` and `docs` into the `dev` branch of the scribe repository.

    push, push, push ...   on dev, nothing is published
    release workflow       opens the pull request into main
    merge                  binaries are built and pushed to scribe

So a merge into `main` here is a publication. It is not a routine step, and that
is why it is deliberate.

## Before you push

Run this once after cloning:

    git config core.hooksPath .githooks

`git push` then runs the same analysis and header checks CI runs, and refuses
the push if any of them fails. It takes about three seconds.

Commit messages follow `[TAG]: message`, the same convention as scribe:

    [DEV]: add the release check to the sdk CLI
    [BUGFIX]: stop the walker resolving the wrong repository root
    [REFACTO]: rename kernel-cli to sdk

`bash .github/commits/check.sh` prints the full list of tags.

## Headers

Every source file carries the proprietary Fiber header, checked in CI. Copy it
from a neighbouring file of the same language.

Do not put the scribe licence in this source. The binaries are published under
the licence that governs the scribe repository; that says nothing about the
source they were built from, and the two must not be confused.
