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

Writes the hosting assets derived from `config.yaml`.

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

### How this file gets written

The CI writes it. When a push to `dev` carries a version that moved, it reads every commit since the
last tag, groups them by their tag, and writes the section before naming that commit. The commits
that only raise the version or write this file are left out.

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
