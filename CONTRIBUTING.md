# Contributing to scribe

`scribe` is the official CLI of the scribe framework. It is what somebody types to create a project,
to regenerate what that project derives, and to render the stack it runs on. A command that half
works is worse than one that does not exist yet, because the file it wrote is still on disk.

## Contributor License Agreement

Every pull request needs a signed CLA before it can be merged. It is one agreement for the whole
framework and one signature per contributor: signing once covers the five repositories, and there
is nothing to sign again here.

The reason is narrow and worth stating plainly: the licence lets you change your own copy, but it
does not give Fiber any right to your changes. Without a CLA, a patch cannot legally be merged
however good it is.

The agreement and the way to sign it are in
[the framework's `.github/cla/CLA.md`](https://github.com/d-fiber/scribe/blob/dev/.github/cla/CLA.md).
CI checks every commit author of a pull request against the register that repository holds, so a
signature added there takes effect here the moment it lands.

If you cannot sign it, open an issue describing the change instead. A clear description of the
problem is often more useful than the patch anyway.

## The licence, in one paragraph

This repository is under the Mozilla Public License 2.0. You may use it, change it, distribute it,
and combine it with files under any other licence, including a proprietary one. What you owe in
return is per file: the source of every file covered by these terms that you distribute, including
the ones you changed, stays available under the same terms. The full text is in `LICENSE`, and every
file carries the notice.

By opening a pull request you are offering your change under those terms.

## Getting set up

You need the Dart SDK, at the version `pubspec.yaml` asks for, and a checkout of the framework as a
sibling directory named `scribe`. The ops tests read the real capacity files and compose templates
that ship, so they have nowhere to read from without it.

```
Fiber/scribe/
  scribe/            the framework
  scribe_tools/      this repository
```

```sh
dart pub get
git config core.hooksPath .githooks
dart test
```

The hooks line is worth the five seconds: `pre-push` runs what CI runs, so a fault stays in your
terminal instead of turning up somewhere it blocks a release. `git push --no-verify` skips it when
you know what you are doing.

That is the whole of it. When you want to run what you just changed the way a person will run it:

```sh
bash tool/build.sh
./out/scribe --version
```

## Where your work goes

Everybody pushes to `dev`. There is no feature branch to make and no pull request to open, unless
you are working from a fork, in which case the pull request targets `dev` too. `main` is not
somewhere anybody pushes; the section on versions below says how it moves.

## Before you push

Read `STYLE.md` first. It says what the code has to look like to be read by somebody who did not
write it, and it is what your change is reviewed against. `TESTING.md` says what the proof has to
look like.

CI runs four checks, and the `pre-push` hook runs the same four before your push leaves:

```
verify    tool/test.sh: it resolves, analyses, checks the formatting and runs the suite
headers   every source file carries the licence notice
commits   every message is tagged and under 72 characters
version   the version is in the one place that holds it, and the changelog accounts for it
```

`bash tool/test.sh` on its own covers the first of the four. The other three are why the hook is
worth the five seconds of setup: they fail for reasons the suite never sees.

A file you add carries the licence notice, copied from the file next to it. That is what `headers`
refuses, and it refuses it after you pushed rather than before, unless the hook is on.

### Run what you wrote

Not the tests alone. The command itself, through the compiled binary, the way somebody would type
it, and then the way somebody would get it wrong. A refusal that does not refuse is a whole bug, and
no unit test on the layer below will find it.

```sh
bash tool/build.sh

cd <somewhere next to a framework checkout>

scribe create trial --sdk js       # the way it is meant to go
scribe create Trial                # a name the rule refuses
scribe create trial --sdk cobol    # an SDK the framework does not carry
scribe create trial                # a second time, over something already there
```

Then run the generators inside what you just wrote, which is the only tree with a real `config.yaml`
in it:

```sh
cd trial
scribe gen routes   # and read the table it wrote
scribe doctor       # and read what it says is missing
scribe gen code     # which refuses outright when config.yaml is not valid
```

A command that writes is worth running twice: the second run is the one that finds out whether it
overwrites, appends, or refuses.

### Write the test that would have caught it

A fault you found gets a test, written before the fix and failing without it. A rule, a refusal or a
limit gets one too: those paths are never walked by ordinary use, so nothing will report the day
they stop working.

`TESTING.md` says when a test is owed, and how the two levels of test here are written.

## Adding a command

A command is a file. A command with more than one file is a file next to a directory of the same
name, and what it needs that others also need does not live in either.

```
lib/src/commands/secrets.dart            the command
lib/src/commands/secrets/                what only it needs, the report it prints included
lib/src/secrets.dart                     the store, which the command is one caller of
test/secrets_test.dart                   the store, called directly
test/commands/secrets_test.dart          the command, run through the runner
```

A command reads its arguments, calls what does the work, and says what happened. That is all it
does; `STYLE.md` points 10 to 12 say why, and what it looks like when it does more.

```dart
/// Rewrites the route table the worker reads at startup, from the tree of `lib/src/`.
class GenRoutesCommand extends ScribeCommand {
  /// Takes no option: the table is read off the tree of `lib/src/`.
  GenRoutesCommand();

  @override
  String get name => 'routes';

  @override
  String get description => 'Walk lib/src/<node>/ and write the route table the worker reads at startup.';

  @override
  Future<ScribeCommandResult> runCommand() async {
    await generateRoutes();
    return const ScribeCommandResult.success();
  }
}
```

Adding one means four things, and the last two are the ones people forget:

```
lib/src/commands/<command>.dart      the command, licence notice included
lib/src/<subject>.dart               the rules it needs, if they are not there yet
test/commands/<command>_test.dart    a test through the runner, reading what it said
CHANGELOG.md                         what it takes and what it answers
```

A command also gets a paragraph in `README.md` saying what it is for. Not the flags, which belong in
the changelog, but what somebody would come to that command for.

A command that reaches for an external program declares it in `requiredTools` instead of looking for
it itself, and one that has to run at the root of a project declares `requiresProject`. Both are
checked and refused before `runCommand` is reached, which is why no command opens with a guard.

## Commit messages

```
[TAG]: message
```

In English, imperative, no full stop, subject under 72 characters. The eleven tags: `DEV`,
`BUGFIX`, `REFACTO`, `DOC`, `TEST`, `CI`, `PERF`, `SECURITY`, `BREAKING`, `REVERT`, `CHORE`. A
merge commit is taken as it is, since its message starts with `Merge `.

The same eleven are written in `.github/commits/check.sh`, which the CI runs, and in
`.github/rulesets/dev.json`, which GitHub refuses a push against. A tag that is not in all three is
not a tag.

A message names something you can go and check in the diff. It is read in six months by somebody
looking for why a line exists, and what they need is the fact, not what you thought of your work
that afternoon.

```
No
[DEV]: various improvements
[DEV]: add comprehensive route validation
[BUGFIX]: fix bug

Yes
[DEV]: refuse two files answering the same route
[BUGFIX]: stop gen code from reading the project SQL twice
[DOC]: say where the rules a command works with go
```

If you cannot write the message in one line, the commit holds two things and wants splitting.

**One commit, one subject.** A working tree almost always holds unrelated things at once, and that
is two commits rather than one. It is what makes the history readable, `git revert` usable, and
`git bisect` able to name a culprit.

```
No
[DEV]: add gen hosting and pin the runner version

Yes
[DEV]: add gen hosting
[CHORE]: pin the Dart SDK the runner installs
```

## Versions, tags and main

Nothing raises the version for you. You raise it in `pubspec.yaml`, which is the only place that
holds it: `tool/build.sh` reads it from there and hands it to the compiler, so a build says the
version its pubspec said and there is nothing to keep in step by hand.

A build made another way says `0.0.0`. That is what `dart run` reports, and it is not a version any
release carries.

You do not write the changelog either. When a push to `dev` carries a version that has moved, the CI
reads every commit since the last tag, groups them by their tag, writes the section, commits it, and
only then names that commit `v1.0.1`. What you write is the commit message; the section is made of
them.

```
## 1.0.1

DEV:

- [DEV]: refuse two files answering the same route (a1b2c3d)

BUGFIX:

- [BUGFIX]: stop gen code from reading the project SQL twice (e4f5a6b)

CI:

- [CI]: pin the Dart SDK the runners install (9f8e7d6)
```

The headings come in the order somebody reading it cares about: what breaks them, what they have to
upgrade for, what they gain, what stopped hurting, and the rest behind it.

The commits that only raise the version or write the changelog are left out of it, since they are
the bookkeeping rather than the work.

`dev` can run three versions ahead of `main` and nothing is waiting on anybody.

`main` moves when the owner decides it moves, and nobody else. GitHub refuses a push to it from
everybody; the only two things it lets through are the owner and one deploy key, which exists so
that the `promote` workflow can do its one job. That workflow is run by hand and takes the version
being put out. It refuses anybody else who asks, it refuses a version `dev` does not hold, and it
refuses a version that was never tagged. Then it merges, writes the release from the changelog
sections `main` had not yet seen, builds the three binaries and attaches them to that release, which
is where `tools/install.sh` puts `scribe` on a machine from.

Binaries are never committed, here or there. Three platforms come to about twenty megabytes a
version, and git keeps every one of them for good, in every clone anybody ever makes.

Your work is done when it is on `dev` and the CI is green. What happens to it afterwards is not
something you have to wait for or ask about.

## Where the work stops

Some things are not yours to decide alone. Stop, and say what you found.

```
A secret in the diff              a token, a key, a .env, a long base64 in a config file
A binary or a generated file      out/ is ignored for a reason, and so is .dart_tool/
A debugging leftover              a print you meant to remove, a test narrowed with a filter
A file written by tooling         pubspec.lock edited by hand rather than by pub
A golden replaced rather than read  fixtures/sizing_golden.json is a photograph, not an output
A change you cannot explain       a file you did not touch, modified, and you do not know why
```
