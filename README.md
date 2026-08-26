# scribe

The official CLI of the [scribe](https://github.com/d-fiber/scribe) framework.

It is the one command a project built on scribe is worked through. It writes the project,
rewrites everything the project derives from what it declares, sizes and renders the stack it
runs on, keeps its secrets, and moves the framework checkout the project sits next to.

## The two sides of the one CLI

`scribe` renders a project. Somebody building an application runs it, and never opens the
framework.

The `pkg` family works on the framework's own packages: it writes one, checks it, and says what
is wrong inside it. It reads a framework checkout rather than a project, which is why it sits
under its own family rather than beside `create` and `gen`.

## Getting it

You already have it. A framework checkout carries its built tools in `tools/`, put there when the
framework was installed, so `scribe` sits beside the other tools with nothing to build and no
version to keep in step by hand.

To type `scribe` from anywhere rather than the path it sits at, link it once into a directory
already on your `PATH`:

```sh
ln -sfn <scribe>/tools/<platform>/scribe ~/.local/bin/scribe
```

## Building it yourself

Only for working on `scribe` itself. What a user runs is the tool that came with the framework, and
a build made here is a build only this machine has.

```sh
bash tool/build.sh
```

The binary lands in `out/scribe`, which git ignores, so a build never reaches a commit.

## How the CLI is shaped

Most commands are reached by their own word:

```
scribe <command> [arguments]
```

`gen` is the one that holds others, and a command under it is reached through it:

```
scribe gen <command>
```

A word that holds others and is typed without one of them is a misuse, and what comes back is the
list of what sits under it.

Four flags belong to the tool rather than to any command. `--version` prints the version of the
build and leaves. `--verbose` says everything, including the stack trace of a failure the tool did
not expect. `--quiet` says nothing but what went wrong. `--yes` answers every question in advance,
which is how a script runs.

Every command leaves 0 when it did what it was asked, 1 when it found something wrong with what it
was pointed at, and 64 when it was called in a way that does not mean anything.

`scribe help` lists what exists, and `scribe help gen` lists what sits under `gen`. This file says
what each command is for; `CHANGELOG.md` says what each one takes and what it answers.

## The commands

### `create`

Writes a project into `./<name>`, from the templates the framework carries, against the SDK the
endpoints will be written in. It initialises no repository and runs no generator: what it writes is
what the templates hold.

The SDKs it offers come from `scribe/sdk/` of the framework next to you, never from a list inside
the tool, so a target that appears there appears in the menu.

### `gen`

Everything the project derives from what it declares. Four commands sit under it, and running `gen`
alone runs all four.

`gen code` rewrites the import map, the enums, the row and table types and the relations, from
`config.yaml` and the project SQL. `gen routes` walks `lib/src/<node>/` and writes the route table
the worker reads at startup. `gen docs` rebuilds the OpenAPI document of every surface the API
source declares. `gen hosting` writes the hosting assets derived from `config.yaml`.

Nothing here is written by hand and nothing here is edited: every file it produces opens with a line
saying so and naming the command that rewrites it.

### `secrets`

Lists, adds and removes what a project carries in `secrets.age`. The file is committed and the key
is not. Values are never printed, only names, because a secret shown on a terminal ends up in a
scrollback buffer and in a screenshot.

### `doctor`

Reports what this machine and this project are missing, `flutter doctor` style. It fixes nothing
unless `--rescue` is passed, and then only what a machine can fix on its own.

### `upgrade` and `downgrade`

Move the framework checkout the project sits next to. `upgrade` brings it to the newest version on
the release branch; `downgrade` puts it back on an older one, picked from the list it prints.

They move the checkout and nothing else. The tool running them stays the build it was installed as.

## Working on it

`CONTRIBUTING.md` says how a change is made and what it has to pass before it is opened.
`STYLE.md` says what the code has to look like, which is what a review is done against.
`TESTING.md` says what the proof has to look like.

## Layout

```
lib/
  runner.dart                            where the process learns how it ends
  src/base/                              what every command leans on
  src/globals.dart                       where everything the tool says goes
  src/runner/                            the command, its result, the group, the runner
  src/commands/<command>.dart            one command
  src/commands/<command>/                what that command alone needs
  src/<subject>/                         the rules several commands work with
  src/<subject>.dart                     a subject small enough for one file
```

A command is a file, and a command with more than one file is a file next to a directory of the same
name. What several commands share does not live inside any of them: `ops/` holds the sizing and the
compose render, and `project.dart`, `dependencies.dart`, `secrets.dart` and the rest hold one
subject each.

## Licence

Mozilla Public License 2.0. The terms are in `LICENSE`, and each file carries the notice.
