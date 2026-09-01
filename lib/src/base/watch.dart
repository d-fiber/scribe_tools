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

import 'dart:async';
import 'dart:io' as io;

import 'package:file/file.dart';

/// Watches directories for a change, and pulses once one settles.
///
/// A real change is read from the operating system, and [FileSystem] cannot
/// answer that on its own: a `MemoryFileSystem` throws the moment anything
/// asks it to watch itself, the same way it never starts a real process. This
/// is therefore watched the way a process is run, through its own seam in
/// `globals` instead of through [FileSystem], so a test replaces it with one
/// that pulses on command rather than one backed by a real directory.
abstract class Watcher {
  /// Pulses once, debounced by [debounce], for every burst of change under or
  /// to any of [entities], a mix of directories watched recursively and
  /// single files. An entity that does not exist yet is skipped rather than
  /// refused, since a project only grows into what a command watches as it is
  /// built out.
  Stream<void> watch(List<FileSystemEntity> entities, {Duration debounce = const Duration(milliseconds: 300)});
}

/// Watches the real file system, through `dart:io` directly.
///
/// Not through [FileSystem]: that abstraction exists to be replaced in a
/// test, and there is exactly one real way to watch a directory, the way
/// there is exactly one real way to start a process. A test reaches for a
/// different [Watcher] instead of a different file system underneath this
/// one, the same way it reaches for a different `ProcessRunner`.
class LocalWatcher implements Watcher {
  /// Watches for real.
  const LocalWatcher();

  @override
  Stream<void> watch(List<FileSystemEntity> entities, {Duration debounce = const Duration(milliseconds: 300)}) {
    final List<Stream<io.FileSystemEvent>> streams = <Stream<io.FileSystemEvent>>[
      for (final FileSystemEntity entity in entities)
        if (entity.existsSync())
          entity is Directory ? io.Directory(entity.path).watch(recursive: true) : io.File(entity.path).watch(),
    ];

    if (streams.isEmpty) return const Stream<void>.empty();

    final List<StreamSubscription<io.FileSystemEvent>> subscriptions = <StreamSubscription<io.FileSystemEvent>>[];
    Timer? pending;
    late final StreamController<void> controller;

    controller = StreamController<void>(
      onListen: () {
        for (final Stream<io.FileSystemEvent> stream in streams) {
          subscriptions.add(
            stream.listen((io.FileSystemEvent _) {
              pending?.cancel();
              pending = Timer(debounce, () => controller.add(null));
            }),
          );
        }
      },
      onCancel: () async {
        pending?.cancel();
        for (final StreamSubscription<io.FileSystemEvent> subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );

    return controller.stream;
  }
}

/// A [Watcher] a test drives by hand, instead of one backed by a real directory.
///
/// [watch] never reads the directories it is given: every call opens a stream
/// this fake keeps a handle to, and [change] pulses every one of them at
/// once. A test
/// starts a `--watch` command without awaiting it, calls [change] as many
/// times as it wants a rerun, then [stop] to end the loop and let the
/// command's own `Future` resolve.
class FakeWatcher implements Watcher {
  final List<StreamController<void>> _controllers = <StreamController<void>>[];

  /// Every call to [watch] this fake has answered, one list per call.
  final List<List<FileSystemEntity>> requests = <List<FileSystemEntity>>[];

  @override
  Stream<void> watch(List<FileSystemEntity> entities, {Duration debounce = const Duration(milliseconds: 300)}) {
    requests.add(entities);
    final StreamController<void> controller = StreamController<void>();
    _controllers.add(controller);
    return controller.stream;
  }

  /// Pulses every open [watch] stream once, as if something had changed.
  void change() {
    for (final StreamController<void> controller in _controllers) {
      controller.add(null);
    }
  }

  /// Closes every open [watch] stream, ending whatever loop was reading one.
  Future<void> stop() async {
    for (final StreamController<void> controller in _controllers) {
      await controller.close();
    }
  }
}
