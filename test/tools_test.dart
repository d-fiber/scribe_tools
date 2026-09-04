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

import 'package:fiber_shell/fiber_shell.dart';
import 'package:scribe_tools/src/tools.dart';
import 'package:test/test.dart';

PackageManager _manager(String name) =>
    PackageManager.known.firstWhere((PackageManager manager) => manager.name == name);

void main() {
  group('the command a package manager installs a tool with', () {
    test('homebrew installs a formula or cask by name, and needs no privilege', () {
      final PackageManager brew = _manager('homebrew');

      expect(commandArgv(brew.installCommand('docker')), <String>['brew', 'install', 'docker']);
      expect(brew.needsPrivilege, isFalse);
    });

    test('winget installs by exact identifier, silently, and needs no privilege', () {
      final PackageManager winget = _manager('winget');

      expect(commandArgv(winget.installCommand('Docker.DockerDesktop')), <String>[
        'winget',
        'install',
        '--silent',
        '--exact',
        '--id',
        'Docker.DockerDesktop',
      ]);
      expect(winget.needsPrivilege, isFalse);
    });

    test('scoop installs an app by name, and needs no privilege', () {
      final PackageManager scoop = _manager('scoop');

      expect(commandArgv(scoop.installCommand('git')), <String>['scoop', 'install', 'git']);
      expect(scoop.needsPrivilege, isFalse);
    });

    test('apt-get installs a package, answering yes to every prompt, and needs privilege', () {
      final PackageManager apt = _manager('apt');

      expect(commandArgv(apt.installCommand('docker.io')), <String>['apt-get', 'install', '--assume-yes', 'docker.io']);
      expect(apt.needsPrivilege, isTrue);
    });

    test('dnf installs a package, answering yes to every prompt, and needs privilege', () {
      final PackageManager dnf = _manager('dnf');

      expect(commandArgv(dnf.installCommand('docker')), <String>['dnf', 'install', '--assumeyes', 'docker']);
      expect(dnf.needsPrivilege, isTrue);
    });

    test('pacman synchronises and installs without confirming, and needs privilege', () {
      final PackageManager pacman = _manager('pacman');

      expect(commandArgv(pacman.installCommand('docker')), <String>['pacman', '-S', '--noconfirm', 'docker']);
      expect(pacman.needsPrivilege, isTrue);
    });

    test('apk adds a package by name, and needs privilege', () {
      final PackageManager apk = _manager('apk');

      expect(commandArgv(apk.installCommand('docker')), <String>['apk', 'add', 'docker']);
      expect(apk.needsPrivilege, isTrue);
    });
  });
}
