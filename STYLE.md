# Coding style

I wrote this for whoever opens a file here without having written it. Every rule below is followed
by what it looks like when you get it wrong and when you get it right, because a rule you have to
interpret is a rule everybody interprets differently.

Read it once before your first change. After that, the examples are enough.

---

## 1. Write like the file next to yours

The surrounding code decides the form. Naming, splitting, the way an error is raised, the order of
declarations. A better answer that is foreign to the code it joins is still the wrong answer.

```dart
// No: this repository raises ToolExit and answers a result. Nothing here does either.
void generateRoutes() {
  final Directory src = Directory('lib/src');
  if (!src.existsSync()) {
    stderr.writeln('no lib/src');
    exit(1);
  }
}

// Yes: the fault carries its sentence, and the runner decides what the process does with it.
static Future<DiscoveredSource> discover() async {
  final Directory src = globals.project.sources;
  if (!src.existsSync()) {
    throwToolExit('[gen:routes] ${src.path} is missing: create lib/src/ first.');
  }
  ...
}
```

---

## 2. Name the thing, not its category

A name that could sit on anything names nothing.

```dart
// No
void process(Map<String, dynamic> data) { ... }
class ManifestHelper { ... }
class ProjectUtils { ... }

// Yes
DiscoveredSource scan(Directory src, String projectRoot) { ... }
List<Col> parseAlterAddColumns(String body) { ... }
```

---

## 3. A function does the work its name promises, and nothing else

If the honest name contains "and", there are two functions.

```dart
// No: the caller who only wanted to read cannot say so, and the write happens anyway.
ScribeManifest loadAndGenerate(Directory root) { ... }

// Yes
ScribeManifest load(File file) { ... }
Future<void> generateRoutes() async { ... }
```

---

## 4. A side effect that the name does not announce is a lie

A function that reads changes nothing. A function that checks writes nothing.

```dart
// No: reading the manifest also creates the generated directory. The day doctor reads
// one to report on it, doctor has written into the project it was only looking at.
ScribeManifest load(File file) {
  Directory(p.join(file.parent.path, '.app')).createSync(recursive: true);
  return ScribeManifest._(...);
}

// Yes
ScribeManifest load(File file) => ScribeManifest._(...);
```

---

## 5. One level of abstraction per function

The function that orchestrates calls named steps. It does not open a file between two of them.

```dart
// No: two named steps and one piece of plumbing, at the same indentation.
Future<void> generateRoutes() async {
  final DiscoveredSource source = await RouteScanner.discover();
  await globals.project.generated.sdk.create();
  final File out = globals.fs.file(p.join(globals.project.generated.sdk.path, 'routes.ts'));
  await out.parent.create(recursive: true);
  await out.writeAsString(RoutesEmitter(source).render(header));
}

// Yes: the plumbing has a name, and the body reads as a list of steps.
Future<void> generateRoutes() async {
  final DiscoveredSource source = await RouteScanner.discover();
  await globals.project.generated.sdk.create();
  await globals.project.generated.sdk.routes.writeAsString(RoutesEmitter(source).render(header));
}
```

---

## 6. Past three parameters, a type is missing

And a boolean in a parameter list asks for two named functions.

```dart
// No: what does this call say? Nothing.
render(project, 16, 32, 64, true);

// Yes
ComposeRender(project: project).render(const Hardware(cores: 16, threads: 32, memoryGb: 64));
```

---

## 7. A class exposes what its name justifies

Read the name, then the list of members. A member that surprises belongs to another class.

```dart
// No: a manifest that knows how to reach the disk and how to talk to a terminal.
class ScribeManifest {
  final String name;
  final List<String> dependencies;

  void save(String path) { ... }
  void printTo(Logger logger) { ... }
}

// Yes: it holds what config.yaml says, and the rest belongs to whoever does it.
class ScribeManifest {
  /// The project name, as `config.yaml` spells it.
  String get name => ...;

  /// The modules the project asks for by name.
  List<String> get dependencies => ...;
}
```

---

## 8. An object is valid as soon as it is built

Not after three calls in the right order.

```dart
// No
final ProjectScaffold scaffold = ProjectScaffold();
scaffold.name = 'trial';
scaffold.target = target;

// Yes
final ProjectScaffold scaffold = ProjectScaffold(root: root, name: 'trial', target: target, templates: templates);
```

---

## 9. The third use moves into the shared place

Two uses, look. Three, share. And what moves loses its context: a shared function that needs a
parameter to tell its callers apart is two functions, not one.

```dart
// No: shared, then widened by one branch per caller.
String describe(Object thing, {required bool asModule}) { ... }

// Yes
String describeModule(Dependency dependency) { ... }
String describeSurface(DocsSurface surface) { ... }
```

Where it goes: what one command needs stays under `lib/src/commands/<command>/`. What several
commands need becomes a subject of its own, `lib/src/<subject>.dart` or a directory when one file
stops holding it. `dependencies.dart`, `project.dart`, `secrets.dart` and `ops/` each got there that
way. There is no `utils.dart` and there is not going to be one.

---

## 10. A command is thin

It reads its arguments, calls what does the work, and says what happened. The work lives beside its
rules, where a test reaches it without a command around it.

```dart
// No: the rule lives in the command, so nothing can test it without running the command.
Future<ScribeCommandResult> runCommand() async {
  final String name = argResults!.rest.first;
  if (!RegExp(r'^[a-z_]+$').hasMatch(name)) throwToolExit('bad name');
  Directory(p.join(inside, name)).createSync();
  ...
}

// Yes
Future<ScribeCommandResult> runCommand() async {
  await generateRoutes();
  return const ScribeCommandResult.success();
}
```

What a command needs before it runs is declared, not checked in its body. `requiresProject`,
`requiresCompleteManifest` and `requiredTools` are read and refused by the runner, which is why no
`runCommand` opens with a guard.

---

## 11. A command never writes to the terminal, and never ends the process

It goes through the logger, and it answers a result or raises a `ToolExit`. The runner is the only
place that knows what a status means.

```dart
// No: nothing can assert on this, and the process dies where the fault was found.
print('Wrote $path');
exit(1);

// Yes
globals.logger.printStatus('Wrote $path');
throwToolExit('$path already exists. Pick another name, or remove it first.');
```

---

## 12. A fault a person can act on is a sentence

Name what is wrong, and say what to do about it.

```dart
// No
throwToolExit('invalid dependency');

// Yes
throwToolExit(
  'config.yaml: unknown dependency "$path". The known ones are ${known.join(', ')}.',
);
```

---

## 13. Every exported member carries a `///`

`public_member_api_docs` refuses one that does not. The comment goes above the declaration, and the
form of its first phrase announces what is being documented.

```dart
/// Calls [visit] on every `.sql` under [dir], however deep.
Future<void> walkSqlFiles(Directory dir, Future<void> Function(File file) visit) async { ... }

/// The number of api containers to start, one per two hardware threads, capped at 64.
int get apiReplicas => ...;

/// Whether the number of its containers depends on the machine.
bool get isReplicated => ...;

/// One service, as the module that owns it declares it.
class ServiceCapacity { ... }
```

A verb for a function whose effect is the point, a noun phrase for one whose answer is the point and
for anything that holds a value, `Whether` for a boolean, and a noun phrase describing one instance
for a class.

---

## 14. A function body carries no comment

What you were about to write in the middle goes up onto the declaration, where the caller sees it.

```dart
// No: only whoever opens the implementation will ever read this.
List<Col> parseColumns(String body) {
  // A table constraint written over several lines has to be skipped whole,
  // which is what the parenthesis count is for.
  ...
}

// Yes: whoever calls it sees the constraint on hover.
/// The columns declared in the body of a `create table`.
///
/// A table constraint is not a column, and one written over several lines has to
/// be skipped whole, which is what the parenthesis count is for. A line that
/// looks like neither is dropped rather than guessed at.
List<Col> parseColumns(String body) { ... }
```

When it takes more than a few sentences, it goes into the internal documentation and the declaration
keeps the line saying a constraint exists.

---

## 15. An exported class documents every field, not the interesting ones

Two fields out of five documented reads as a claim that the other three have no unit, no range and
no invariant. The reader ends up distrusting all five.

```dart
// No
class Col {
  final String name;

  /// The TypeScript type this column becomes, `| null` included when it is nullable.
  final String ts;

  final String? enumName;
}

// Yes
class Col {
  /// The column name, as the SQL spells it.
  final String name;

  /// The TypeScript type this column becomes, `| null` included when it is nullable.
  final String ts;

  /// The Postgres enum this column is of, null when its type is not an enum.
  final String? enumName;
}
```

The first line teaches almost nothing, and that is the point. It costs one line and removes the
doubt from the other two.

---

## 16. A comment says why, never what

The what is on the line below, and it will still be true when the comment has stopped being so.

```dart
// No
/// Returns the total.
int get total => _total;

// Yes
/// The weight of every service that starts, which is what a share is taken out of.
///
/// A service whose profile is switched off stays in [services] and takes no
/// share, since the compose document declares it and its limit still has to be written.
final int total;
```

---

## 17. A test file carries no comment

The name of the case and the assertion message are what show up when the suite goes red. A comment
shows up nowhere.

```dart
// No
test('render', () {
  // a module the project did not ask for should contribute nothing
  ...
  expect(services.keys.length, 9);
});

// Yes
test('a module the project did not ask for contributes nothing', () {
  ...
  expect(services.keys, isNot(contains('opensearch')), reason: 'search is not in the selection');
});
```

---

## 18. Setup that needs explaining wants a name, not a comment

```dart
// No
final Directory d = fs.directory('/work/koko'); // where the project sits, below the framework

// Yes
final Directory projectRoot = _vendorFramework(fs, '/work/koko/scribe');
```

---

## 19. Write the way you would say it out loud

Everything you write here gets read by somebody: a comment, a commit message, a test name, an
assertion message, a log line, whatever a command prints. Write it in sentences, with a subject and
a verb, the way you would explain it to whoever is sitting next to you.

What gives away text that was not written for a person is punctuation doing the job of a word.
An arrow standing in for "gives", a row of equals signs standing in for a heading, a slash standing
in for "per".

```
No
14 paths on 3 nodes -> .trial/sdk/js/routes.ts
=== DONE! ===

Yes
14 paths on 3 nodes, written to .trial/sdk/js/routes.ts
Wrote ./trial
```

If you would not say it that way at a desk, do not write it in the source.

---

## 20. Say the real thing

The words that sell something say nothing about it. So do the phrases that describe a piece of code
without naming anything in it. Both of them survive forever, because there is nothing in them
anybody could ever prove wrong.

```
No
Handles the edge case for robustness.
Does the work, for performance reasons.

Yes
Two files answering one route means one of them is dead code, and picking a winner here would
make which one depends on the order the directory happened to be read in.
```

The test: somebody who knows nothing of the context understands it in one reading. If it takes two,
the text is what has to change, not the reader.

---

## 21. The source is in English

Whatever language the work is discussed in. Identifiers, comments, logs, test names, and what a
command prints.

---

## What the tools hold you to

```sh
dart analyze
dart format --line-length 120 lib bin test
dart test
```

`public_member_api_docs` refuses an exported member nobody documented. `always_specify_types` and
`always_declare_return_types` keep the types written down. The four `unused_*` rules are errors, so
code nothing reaches does not survive a commit.

None of that judges whether the code is any good. That is what the twenty-one points above are for.
