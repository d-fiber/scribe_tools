// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import '../process.dart';

class DockerCompose implements ShellCommand {
  DockerCompose(this._files, {this.projectDirectory, this.envFile, this.profiles = const <String>[]});

  final List<String> _files;
  final String? projectDirectory;
  final String? envFile;
  final List<String> profiles;

  @override
  final String executable = 'docker';

  final List<String> _tokens = <String>[];

  @override
  List<String> get args => <String>[
    'compose',
    for (final String file in _files) ...['-f', file],
    if (projectDirectory case final String dir) ...['--project-directory', dir],
    if (envFile case final String path) ...['--env-file', path],
    for (final String profile in profiles) ...['--profile', profile],
    ..._tokens,
  ];

  DockerCompose up() {
    _tokens.add('up');
    return this;
  }

  DockerCompose down() {
    _tokens.add('down');
    return this;
  }

  DockerCompose ps() {
    _tokens.add('ps');
    return this;
  }

  DockerCompose exec() {
    _tokens.add('exec');
    return this;
  }

  DockerCompose run() {
    _tokens.add('run');
    return this;
  }

  DockerCompose rm() {
    _tokens.add('--rm');
    return this;
  }

  DockerCompose entrypoint(String value) {
    _tokens.addAll(<String>['--entrypoint', value]);
    return this;
  }

  DockerCompose detach() {
    _tokens.add('-d');
    return this;
  }

  DockerCompose removeOrphans() {
    _tokens.add('--remove-orphans');
    return this;
  }

  DockerCompose noDeps() {
    _tokens.add('--no-deps');
    return this;
  }

  DockerCompose restart() {
    _tokens.add('restart');
    return this;
  }

  DockerCompose volumes() {
    _tokens.add('--volumes');
    return this;
  }

  DockerCompose quiet() {
    _tokens.add('--quiet');
    return this;
  }

  DockerCompose noTty() {
    _tokens.add('-T');
    return this;
  }

  DockerCompose service(String name) {
    _tokens.add(name);
    return this;
  }

  DockerCompose command(List<String> value) {
    _tokens.addAll(value);
    return this;
  }
}
