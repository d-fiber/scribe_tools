# Changelog

## 1.0.0

The first build of `scribe`, the official CLI of the scribe framework.

### `scribe create <name> [--sdk <name>]`

Writes a project into `./<name>`, from the templates the framework next to you carries. It
initialises no repository and runs no generator: what it writes is what the templates hold.

`--sdk` names the SDK the endpoints are written against. The choices come from `scribe/sdk/` of the
framework on disk, never from a list inside the tool, so a target that appears there appears in the
menu. When the flag is left out, the tool takes the only SDK available, or asks, or falls back on
the default, and says which of the three happened.

Nothing is ever written over a directory that exists.

### `scribe gen`

Runs the four generators below, in the order they depend on each other.

### `scribe gen code`

Rewrites the import map, the enums, the row and table types and the relations, from `config.yaml`
and the project SQL. It needs `config.yaml` to be valid, not merely present.

### `scribe gen routes`

Walks `lib/src/<node>/` and writes the route table the worker reads at startup. A directory of
`lib/src/` is a node, a `.ts` file under it is a route at the path its own place spells, and a name
starting with `_` is invisible to both.

Two files answering the same route is refused rather than resolved, since picking a winner would
make which one depends on the order the directory happened to be read in.

### `scribe gen docs`

Rebuilds the OpenAPI document of every surface the API source declares, by running the Deno walker
the framework ships. A route filed under a tag nobody declared is refused, naming both.

### `scribe gen hosting`

Writes nothing today. It is the entry point the next hosting asset derived from
`config.yaml` will be written from, kept so that adding one is a function body rather than
a command to bring back.

### `scribe secrets [--set NAME=VALUE] [--unset NAME]`

Lists, adds and removes what a project carries in `secrets.age`. Both flags repeat, and both are
parsed before the store is opened, so a run that is going to fail on a bad name fails before it has
decrypted anything.

With no flag it lists the names, or says how to add the first one when there are none. Values are
never printed.

### `scribe doctor [--rescue]`

Reports what this machine and this project are missing, one section per subject. It fixes nothing
unless `--rescue` is passed, and then only what a machine can fix on its own.

It leaves with 0 when it found nothing wrong, and with 1 when it did.

### `scribe upgrade`

Brings the framework checkout next to the project to the newest version on the release branch. It
refuses a checkout carrying changes that are not committed, rather than moving on top of them.

It says so and leaves with 0 when there is nothing newer.

### `scribe downgrade [version]`

Puts the checkout back on an older version, named or picked from the list it prints, which is every
version older than the one here, newest first, read from the history of `VERSION`. It leaves the
checkout on a detached head, and `scribe upgrade` is the way back.

### `scribe clean [--dry-run]`

Removes what `forge` and `gen` derived, so the next run writes it fresh. In a project that is
`.<name>/`, the derived tree `forge` and `gen` rewrite; in a package it is `.scribe/`, holding only
`resolution.json`. It never touches `.scribe/state/`, the OpenTofu state `deploy` provisioned:
that one stays `destroy`'s to take down. `--dry-run` lists what would go without removing it.

### `--machine`

`status`, `doctor` and `forge` each answer `--machine` with one line of JSON instead of the report
a person reads: what a target is running, what the machine and the project are missing, what a
project or a package resolved to. Nothing else reaches standard output when it is passed.

### `scribe completion bash|zsh|fish`

Prints a shell completion script, read off the command tree itself rather than a list kept apart
from it. Bash and zsh share one generator, zsh reaching it through `bashcompinit`; fish gets its
own, since it completes by condition rather than by position. Only command words and long flag
names complete, never a flag's own value.

### `--watch`

`analyze`, `forge` and `run` answer `--watch` by running their own body again every time what they
watch changes, instead of once. `analyze` watches the roots it was given; `forge` watches `lib/`
and the manifest; `run` watches `lib/` alone, and only on the workstation a target with no host
deploys to, restarting the api and, with `--worker`, the worker, since neither container reacts to
its own mounted code on its own.

### `scribe daemon`

Answers requests as JSON lines on standard input, one line back per request, until told to stop:
`doctor`, `forge` and `status`, each the same document `--machine` on the command of the same name
would answer, plus `watch.start` / `watch.stop`, which push a `forge.changed` event on every change
instead of blocking on one. It is what an editor keeps open instead of shelling out to the CLI for
every question.

### How this file gets written

The CI writes it, once the version has moved and been tagged for the first time. When a push to
`dev` carries a version that moved, it reads every commit since the last tag, groups them by their
tag, and writes the section before naming that commit. The commits that only raise the version or
write this file are left out. Before the first tag, as while `1.0.0` is still unreleased, this
section is kept by hand instead.

### What a newer framework looks like

Any command says so at the top when the checkout it is working in is behind the release branch, then
carries on with what it was asked to do. Nothing is fetched to find out: it reads what the last
fetch brought in, and starts the next one detached, so the command that was typed never waits on the
network.

### `scribe --version`

Prints the version of the build and leaves. It is the version `pubspec.yaml` held when the binary
was compiled, handed to the compiler by `tool/build.sh`. A build made another way says `0.0.0`.

### `scribe --verbose`, `--quiet`, `--yes`

`--verbose` says everything, including the stack trace of a failure the tool did not expect.
`--quiet` says nothing but what went wrong. `--yes` answers every question in advance, which is how
a script runs a command that would otherwise ask.
