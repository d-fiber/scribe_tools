# Changelog

## 1.0.0

BREAKING:

- [BREAKING]: put this repository under the Mozilla Public License 2.0 (58dc8f4)
- [BREAKING]: rebuild the CLI around an injected context (48533ad)
- [BREAKING]: ship the tools as release assets, not commits (58e5aef)

DEV:

- [DEV]: discover a .proto under any protocol directory (45999e8)
- [DEV]: read the ops fragments a package groups by subject (2ea58d4)
- [DEV]: write the imports that wire every mounted module into the host (438c6b4)
- [DEV]: read the modules of both the framework and the packages submodule (92900bc)
- [DEV]: emit the _log.ts sinks the routes table found (dd9b66b)
- [DEV]: size a project from what it actually mounts (8867835)
- [DEV]: say when a newer framework is out, and add upgrade and downgrade (77a4ca4)
- [DEV]: list the tools, and say nothing about a project that is fine (2a6e5e9)
- [DEV]: give doctor a --rescue that fixes what a machine can fix (195ba62)
- [DEV]: say what scribe create accepts, and what it just wrote (b3709c7)
- [DEV]: refuse a wrong command line with what to write instead (9d85586)

BUGFIX:

- [BUGFIX]: name the modules scribe@dev carries, not the ones on this disk (be826ff)
- [BUGFIX]: stop the header check from skipping the gen tree (ad6475d)
- [BUGFIX]: seat realtime connections in the memory the container has (bc5f076)
- [BUGFIX]: read the manifests and the rest contract where they now live (bf41309)
- [BUGFIX]: size redis, the pooler and the body budget in the sdk copy too (0019798)
- [BUGFIX]: size redis, the pooler and the body budget on the machine (d202503)
- [BUGFIX]: give the worker a share so the templates still resolve (89ea311)
- [BUGFIX]: keep the v8 heap cap under the container it runs in (2e60b97)
- [BUGFIX]: create the output directory before dart compile (34da4fe)

PERF:

- [PERF]: size the api heap from the container limit (cdc8ef1)

REFACTO:

- [REFACTO]: let the case names carry what the ops test commented (036c840)
- [REFACTO]: say in words what a generator wrote, instead of an arrow (28f8bca)
- [REFACTO]: make the user CLI the package at the root of this repository (b0f4a9e)
- [REFACTO]: drop the docs walker, which ships with the framework now (f7fb195)
- [REFACTO]: drop the framework CLI, which moved to scribe_dev_tools (0379da5)
- [REFACTO]: find a module by what it carries, not by its manifest (60e3412)
- [REFACTO]: find a module by what it carries, not by its manifest (84cf247)
- [REFACTO]: read a package's ops fragments by subject (b1f36de)
- [REFACTO]: size the stack without the pooler and studio (51a2c2d)
- [REFACTO]: emit the engine imports the foundation package now owns (a038c9f)
- [REFACTO]: scaffold projects from templates/project/ (3486f1d)
- [REFACTO]: read the compose and kong templates from templates/ops/ (3cd90f1)
- [REFACTO]: write the route extractor's source in English (4d217f1)
- [REFACTO]: write the framework CLI's source in English (62eab64)
- [REFACTO]: write the CLI's source in English (eedd1ab)
- [REFACTO]: split doctor into its three sections (7d0bcd7)
- [REFACTO]: pull the sdk choice and the report out of create (4b911ee)
- [REFACTO]: pull the route claims out of the scanner (d78a9b6)
- [REFACTO]: split the openapi document into skeleton, index and portal (c4f3f9c)
- [REFACTO]: split the table generator into a scan and its emitters (8bf2db6)
- [REFACTO]: pull the import map out of the config generator (d3eb3fe)
- [REFACTO]: split the secrets command into edits, report and references (029b769)
- [REFACTO]: drop the explanatory comments (e0198b6)

DOC:

- [DOC]: say what this CLI is, how it is worked on and how it is proved (adf7d55)
- [DOC]: document every exported member (d470f8a)
- [DOC]: document everything under lib/src but the commands (c9754a8)
- [DOC]: document the CLI surface outside the commands (e2b8edf)

TEST:

- [TEST]: retake the sizing golden, now that opensearch-setup is gone (ca5e2ec)
- [TEST]: name the modules the framework carries today (cb91eed)
- [TEST]: name the modules by the address their root gives them (842eeb9)
- [TEST]: cover the log sink scanner and what the emitter binds (320fdf8)
- [TEST]: refuse a container name on a replicated service (2dccab7)

CI:

- [CI]: read the promote key under the name both tool repos use (c31e378)
- [CI]: record the deploy key bypass the way GitHub stores it (cf618e9)
- [CI]: point promote at the deploy key this repository actually holds (8c5b1cb)
- [CI]: run this repository the way scribe_dev_tools is run (67cb1c4)
- [CI]: keep the version in pubspec.yaml and nowhere else (fd59075)
- [CI]: check out the packages submodule with its own key (2106785)
- [CI]: give the CLI job the framework its ops tests read (d41337c)
- [CI]: add a script that builds the CLI binary locally (5a16af0)
- [CI]: realign dev when the promotion had to merge (35ce029)
- [CI]: let promote read the check runs it waits on (54bb4d3)
- [CI]: push main with a deploy key so publish still fires (5eb5dc2)
- [CI]: promote with a merge so no force push is ever needed (7752063)
- [CI]: move main to dev automatically while DEV_PHASE is on (17e3664)
- [CI]: let the owner bypass the rulesets and fix CODEOWNERS (106f3a5)
- [CI]: check out the private scribe repo with the deploy key (59dbfdb)
