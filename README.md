<h1 align="center">
  <img src="https://raw.githubusercontent.com/d-fiber/scribe_tools/main/images/logo-transparent.png" width="96" alt=""><br>
  scribe
</h1>

<h2 align="center">The one command a scribe project runs through.</h2>

<p align="center">
  Write a project, resolve everything it derives from what it declares, size and render<br>
  the stack it runs on, keep its secrets, and move the framework checkout it sits next to.
</p>

<p align="center"><b>It ships with the framework. Create, run.</b></p>

## Commands

| Command                 | What it does                                                                            |
| ----------------------- | --------------------------------------------------------------------------------------- |
| `create [name]`         | writes a project, or a package with `--package`                                         |
| `forge`                 | resolves what a project or a package derives from its manifest                          |
| `secrets`               | lists, adds and removes what a project keeps in `secrets.age`, names only, never values |
| `doctor`                | reports what the machine and the project are missing, and fixes it with `--rescue`      |
| `upgrade` / `downgrade` | move the framework checkout up or down a version                                        |
| `analyze` / `test`      | check or run the suite of a framework package                                           |

`create`, `forge`, `analyze` and `test` also work on the framework's own packages, reading a
checkout instead of a project. `scribe help` lists the rest.

## About Scribe

Scribe is a complete backend you install, not a framework you assemble. Accounts, storage,
realtime, search, and a foundation of cache, queue, cron and rate limiting are already there.

**Install the backend. Write the product. Nothing in between.**

[Framework](https://github.com/d-fiber/scribe) ·
[Packages](https://github.com/d-fiber/scribe_packages) ·
[VS Code extension](https://github.com/d-fiber/scribe_vscode_extensions)

## License

Mozilla Public License 2.0
