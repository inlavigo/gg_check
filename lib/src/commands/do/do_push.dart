// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg/src/commands/can/can_push.dart';
import 'package:gg/src/tools/gg_state.dart';
import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';

/// Pushes the current state.
class DoPush extends DirCommand<void> {
  /// Constructor
  DoPush({
    required super.ggLog,
    super.name = 'push',
    super.description = 'Pushes the current state.',
    IsPushed? isPushed,
    CanPush? canPush,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    GgState? state,
  })  : _processWrapper = processWrapper,
        _isPushedViaGit = isPushed ?? IsPushed(ggLog: ggLog),
        _canPush = canPush ?? CanPush(ggLog: ggLog),
        state = state ?? GgState(ggLog: ggLog) {
    _addParam();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    bool? force,
  }) async {
    // Does directory exist?
    await check(directory: directory);

    // Is everything pushed?
    final isPushedViaGit = await _isPushedViaGit.get(
      directory: directory,
      ggLog: ggLog,
    );

    // Is didPush already set?
    if (isPushedViaGit) {
      final isDone = await state.readSuccess(
        directory: directory,
        key: stateKey,
        ggLog: ggLog,
      );

      if (isDone) {
        ggLog(yellow('Already checked and pushed.'));
        return;
      }
    }

    // Is everything fine?
    await _canPush.exec(
      directory: directory,
      ggLog: ggLog,
    );

    // Write success before pushing
    await state.writeSuccess(
      directory: directory,
      key: stateKey,
    );

    // Execute the commit
    if (!isPushedViaGit) {
      force ??= _forceFromArgs();
      await _gitPush(directory, force);
      ggLog(yellow('Checks successful. Pushed successful.'));
    } else {
      ggLog(yellow('Checks successful. Nothing to push.'));
    }
  }

  /// The state used to save the state of the command
  final GgState state;

  /// The key used to save the state of the command
  final String stateKey = 'doPush';

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final GgProcessWrapper _processWrapper;
  final IsPushed _isPushedViaGit;
  final CanPush _canPush;

  // ...........................................................................
  void _addParam() {
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Do a force push.',
      defaultsTo: false,
      negatable: true,
    );
  }

  // ...........................................................................
  Future<void> _gitPush(Directory directory, bool force) async {
    final result = await _processWrapper.run(
      'git',
      ['push', if (force) '-f'],
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      throw Exception('git push failed: ${result.stderr}');
    }
  }

  // ...........................................................................
  bool _forceFromArgs() {
    final force = argResults?['force'] as bool? ?? false;
    return force;
  }
}