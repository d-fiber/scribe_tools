# Tests

Writing is not finishing. A change is done when it has run, not when it looks right, and "it should
work" is a hypothesis rather than a state.

`STYLE.md` says what the code has to look like. This says what the proof has to look like.

---

## 1. Running is not reading

Rereading your own diff proves nothing: you reread what you meant to write. Go through the real way
in, with real input.

```sh
bash tool/build.sh

cd <somewhere next to a framework checkout>
scribe create trial --sdk js
cd trial && scribe gen routes
```

The case that is meant to be refused counts as much as the case that is meant to pass. That is where
new code breaks, never on the example you had in mind while writing it.

```sh
scribe create Trial              # a name the rule refuses
scribe create trial --sdk cobol  # an SDK the framework does not carry
scribe create trial              # over something already there
scribe gen routes                # from outside a project at all
```

A command that writes is worth running twice. The second run is the one that finds out whether it
overwrites, appends, or refuses.

---

## 2. A test is written when its absence would let the problem come back

Not every change needs one, and pretending otherwise makes the suite noise.

```
It needs one
A fault you found                      it comes back otherwise, and nothing will say so
A rule, a refusal, a limit             ordinary use never walks that path
A function with branches               many cases for very little setup
A behaviour you have just decided      so that nobody undoes the decision by accident

It does not
A rename the compiler checks entirely
A change of wording
A move with no change of behaviour
A tweak to the analysis options
```

When you are unsure, the question is who will tell you if this breaks in six months. When the answer
is nobody, write the test.

---

## 3. There are two levels here, and they are not written the same way

The rules go under `test/<subject>_test.dart`, and they are called directly, with no command around
them.

```dart
test('two files answering one route is refused', () {
  final Directory src = _tree(<String>['users/index.ts', 'users/list.ts']);

  expect(() => RouteScanner.scan(src, '/project'), throwsA(isA<ToolExit>()));
});
```

The commands go under `test/commands/<command>_test.dart`, and they are called the way a person
calls them, through the runner, so that the arguments, the status and what was said are all part of
what is proved.

```dart
test('an SDK the framework does not carry is refused with the list of the ones it has', () async {
  expect(await run(<String>['create', 'trial', '--sdk', 'cobol']), 1);
  expect(logger.errorText, contains('"cobol" is not an SDK this framework carries'));
});
```

A command tested by calling the function underneath it is a command nobody tested. The status it
answers and the sentence it prints are most of what it does.

---

## 4. A command test reads back what the command said

That is what `globals.logger` is for. Register a `BufferLogger` in the context, and let the runner
wrap it the way it wraps the real one, so `-v` and `-q` are exercised too.

```dart
setUp(() {
  fs = MemoryFileSystem.test();
  logger = BufferLogger();
});

Future<int> run(List<String> args) => runner.run(
  args,
  () => <ScribeCommand>[CreateCommand()],
  toolVersion: '1.0.0',
  overrides: <Type, Generator>{FileSystem: () => fs, Logger: () => logger},
);
```

`logger.statusText` holds what was said to the caller, `logger.errorText` what was said to have gone
wrong. Assert on the part of the sentence that carries the meaning, not on the whole of it, or every
reword turns the suite red for nothing.

```dart
// No: the day somebody improves the wording, this fails and teaches nobody anything.
expect(logger.errorText, 'config.yaml: unknown dependency "security/nope". The known ones are '
    'audience, auth, dynamic_links, foundation, realtime, search, storage.\n');

// Yes
expect(logger.errorText, allOf(contains('security/nope'), contains('security/auth')));
```

---

## 5. Anything that touches the disk gets a file system of its own

A `MemoryFileSystem.test()` in `setUp`, registered in the context. Never a path inside the
repository, and never a file system two tests share.

```dart
late FileSystem fs;

setUp(() => fs = MemoryFileSystem.test());
```

The ops tests are the exception, and they read rather than write: they open the real capacity files
and compose templates of the framework checked out next to this one, because a weight edited in the
framework has to move a test here. They are the reason a sibling `scribe` is part of getting set up.

---

## 6. Build the fixture with the code that builds the real thing

A fixture written by hand drifts from what the tool actually produces, and then the tests pass while
the tool is broken.

```dart
// No: the day a project gains a directory, this fixture keeps passing and means nothing.
fs.directory('/work/trial/lib/src').createSync(recursive: true);
fs.file('/work/trial/config.yaml').writeAsStringSync('name: trial\n');

// Yes: the scaffolder writes it, so a change to the layout reaches the tests by itself.
await ProjectScaffold(root: root, name: 'trial', target: target, templates: templates).write();
```

---

## 7. A test you have never seen fail proves nothing

See it red before you see it green. A test written after the fix, passing first time, has
demonstrated nothing and may be checking nothing at all.

It also tends to describe what the code does rather than what it should do, bug included, because
you copied the output into the expectation. Decide the expected value before looking at the result.

---

## 8. When a test goes red, the code is wrong until proven otherwise

Adjusting the expectation removes the only warning you had.

```dart
// No: the render now hands db a different limit, so the test was made to accept it.
expect(services['db']['deploy']['resources']['limits']['memory'], '10.11g');

// Yes: find out which weight moved, and whether it should have.
expect(services['db']['deploy']['resources']['limits']['memory'], '9.71g',
    reason: 'db weighs 2122 against the 5597 this selection starts, not against the 9503 declared');
```

`test/ops/fixtures/sizing_golden.json` is the sharpest case of this. It is a photograph of the whole
sizing table, kept so that a weight or a formula changed by accident shows up as a number that
moved. It does not regenerate itself, and replacing it is a deliberate act: you write a throwaway
program calling `SizingRules(shape, frameworkCapacity()).resolve()` on the six shapes, read the
difference key by key, and then throw the program away.

---

## 9. The name of the case and the assertion message are the whole documentation

They are what shows up when the suite is red. A comment shows up nowhere, so a test file carries
none.

```dart
// No
test('profiles', () {
  // search should only come on when a module asks for it
  ...
  expect(profiles.length, 2);
});

// Yes
test('switches on the profiles the mounted modules declare, and no others', () async {
  expect((await render()).profiles, isEmpty, reason: 'neither auth nor rbac declares a profile');
});
```

When a `reason:` would help, it says what distinguishes this call from the others.

---

## 10. Setup that needs explaining wants a name

```dart
// No
final Directory d = fs.directory('/work/koko/scribe'); // vendored by the block above

// Yes
_vendorFramework(fs, '/work/koko/scribe');
```

A helper shared by the cases of one file lives at the top of that file. A helper shared by several
files lives next to them, the way `test/ops/capacity_source.dart` does, and being shared makes it
code like any other: its surface is documented.

---

## 11. Take away what you made to test

Directories, sample projects, files dropped somewhere to see how the code reacts. Left behind, they
become a state somebody will eventually take for real. `create` writes a real tree on a real disk,
so this is not hypothetical here.

Delete by looking at what you delete. List first, name what goes, and never delete a pattern.

---

## 12. Say what you ran, and say what you did not

A verification you announce without having done it is worse than one you skipped, because it hands
over confidence that rests on nothing.

```
No
Tested, everything passes.

Yes
dart test is green, 226 cases. I ran create and gen routes through the compiled binary,
including the two refusals. I did not try it on Windows, so the path separator in the route
table is unverified there.
```

When something fails, report it with the real output. A failure described from memory loses exactly
the detail that would have explained it.

---

## What runs it

```sh
bash tool/test.sh                        # everything a pull request has to pass
bash tool/test.sh --name 'route table'   # the same, narrowed to one case

dart test                                # the suite alone
dart test test/ops/capacity_test.dart    # one file
```
