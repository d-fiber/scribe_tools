// Copyright (C) 2026 Fiber
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// What you may do:
// - Use this software for any purpose, including commercially, and build and
//   sell your own products on top of it.
// - Change it, and create new works based on it.
// - Distribute copies of it, with or without your changes.
// - Combine it with files under any other licence, proprietary ones included,
//   and licence that larger work on your own terms.
//
// What you must do in return:
// - Keep this notice on every file you received it on.
// - Publish, under these same terms, the source of every file covered by them
//   that you distribute, including the ones you changed, so that whoever
//   receives your version can obtain that source.
// - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
//   trademarks may not be used to endorse or promote what you build, and this
//   licence grants no right to them.
//
// Disclaimer:
// AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
// OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
// NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
// LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
// OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
// KIND OF LEGAL CLAIM.
//
// This header is a summary written for convenience. Where it differs from the
// LICENSE file, the LICENSE file governs.

import 'package:file/file.dart';
import 'package:scribe_tools/src/base/process.dart';
import 'package:scribe_tools/src/globals.dart' as globals;

/// A host reached over SSH, and the three things a deployment asks of it.
///
/// It shells out to `ssh` and `rsync` rather than speaking either protocol,
/// because the user's own configuration, their keys, their jump hosts and their
/// agent all live in `~/.ssh/config`, and a client of our own would ignore every
/// one of them.
class RemoteHost {
  /// Reaches [address], a `user@host` as SSH understands it.
  const RemoteHost(this.address);

  /// The `user@host` the target names.
  final String address;

  /// The home directory of the account that logs in, null when it cannot be read.
  ///
  /// It is asked rather than assumed because the stack has to be laid at a path
  /// that exists, and every bind mount inside the documents is absolute: a
  /// rendered path that is wrong on the host makes the daemon create a directory
  /// where a file should be, and the container dies three layers from the cause.
  Future<String?> home() async {
    final ProcessOutcome outcome = await globals.processRunner.observe(<String>['ssh', address, 'echo \$HOME']);
    if (!outcome.succeeded) {
      globals.logger.printError(outcome.stderr.trim());

      return null;
    }

    final String answer = outcome.stdout.trim();

    return answer.isEmpty ? null : answer;
  }

  /// Copies [stack] to [destination] on the host, and returns whether it landed.
  ///
  /// `--delete` on purpose: a document an earlier deployment wrote and this one
  /// does not is a document Compose would still read.
  Future<bool> ship(Directory stack, String destination) async {
    if (await _run(<String>['ssh', address, 'mkdir -p $destination']) != 0) return false;

    return await _run(<String>[
          'rsync',
          '--archive',
          '--delete',
          '--compress',
          '${stack.path}/',
          '$address:$destination/',
        ]) ==
        0;
  }

  /// Removes [path] on the host, and answers whether it is gone.
  ///
  /// It is the other half of [ship]: a directory of documents left behind is a
  /// deployment somebody can start again by hand long after the project stopped
  /// describing it.
  Future<bool> remove(String path) async => await _run(<String>['ssh', address, 'rm -rf $path']) == 0;

  /// Runs `docker compose` on the host, against the stack laid at [root].
  ///
  /// [documents] are the paths on the host, in the order Compose has to read
  /// them, and [arguments] is the verb and its flags.
  Future<int> compose(
    List<String> arguments, {
    required String root,
    required String projectName,
    required List<String> documents,
  }) => _run(<String>[
    'ssh',
    address,
    <String>[
      'docker',
      'compose',
      '--project-directory',
      root,
      '-p',
      projectName,
      for (final String document in documents) ...<String>['-f', document],
      ...arguments,
    ].join(' '),
  ]);

  Future<int> _run(List<String> command) async {
    globals.logger.printTrace('[remote] ${command.join(' ')}');

    return globals.processRunner.run(command);
  }
}
