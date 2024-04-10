// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg/src/commands/can/can_commit.dart';
import 'package:gg/src/tools/gg_state.dart';
import 'package:gg_args/gg_args.dart';
import 'package:gg_changelog/gg_changelog.dart' as cl;
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:mocktail/mocktail.dart';

final _logTypes = cl.LogType.values.map((e) {
  switch (e) {
    case cl.LogType.added:
      return 'add';
    case cl.LogType.changed:
      return 'change';
    case cl.LogType.deprecated:
      return 'deprecate';
    case cl.LogType.fixed:
      return 'fix';
    case cl.LogType.removed:
      return 'remove';
    case cl.LogType.security:
      return 'secure';
  }
});

cl.LogType _stringToLogType(String e) {
  switch (e) {
    case 'add':
      return cl.LogType.added;
    case 'change':
      return cl.LogType.changed;
    case 'deprecate':
      return cl.LogType.deprecated;
    case 'fix':
      return cl.LogType.fixed;
    case 'remove':
      return cl.LogType.removed;
    case 'secure':
      return cl.LogType.security;
    default:
      throw Exception('Unknown log type: $e'); // coverage:ignore-line
  }
}

// .............................................................................
/// Does a commit of the current directory.
class DoCommit extends DirCommand<void> {
  /// Constructor
  DoCommit({
    required super.ggLog,
    super.name = 'commit',
    super.description = 'Commits the current directory.',
    IsCommitted? isCommitted,
    CanCommit? canCommit,
    Commit? commit,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    GgState? state,
    cl.Add? addToChangeLog,
  })  : _processWrapper = processWrapper,
        _isGitCommitted = isCommitted ?? IsCommitted(ggLog: ggLog),
        _canCommit = canCommit ?? CanCommit(ggLog: ggLog),
        _commit = commit ?? Commit(ggLog: ggLog),
        state = state ?? GgState(ggLog: ggLog),
        _addToChangeLog = addToChangeLog ?? cl.Add(ggLog: ggLog) {
    _addParam();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    String? message,
    cl.LogType? logType,
    bool? updateChangeLog,
  }) async {
    // Does directory exist?
    await check(directory: directory);

    // Is everything committed?
    final isCommittedViaGit = await _isGitCommitted.get(
      directory: directory,
      ggLog: ggLog,
    );

    // Is didCommit already set?
    if (isCommittedViaGit) {
      final isDone = await state.readSuccess(
        directory: directory,
        key: stateKey,
        ggLog: ggLog,
      );

      if (isDone) {
        ggLog(yellow('Already checked and committed.'));
        return;
      }
    }

    // Check needed options
    try {
      logType ??= _getLogTypeFromArgs(isCommittedViaGit);
      message ??= _getMessageFromArgs(isCommittedViaGit, logType);
    } catch (e) {
      // type and message are only needed when there are uncommitted changes.
      if (!isCommittedViaGit) {
        rethrow;
      } else {
        logType = cl.LogType.changed;
        message = '';
      }
    }

    final repoUrl = await _repositoryUrl(directory);

    // Is everything fine?
    await _canCommit.exec(
      directory: directory,
      ggLog: ggLog,
    );

    // Update changelog when a message is given
    updateChangeLog ??= argResults?['log'] as bool? ?? true;
    if (updateChangeLog) {
      await _writeMessageIntoChangeLog(
        directory: directory,
        message: message,
        logType: logType,
        repoUrl: repoUrl,
        commit: isCommittedViaGit,
      );
    }

    // Execute the commit
    if (!isCommittedViaGit) {
      await gitAddAndCommit(
        directory: directory,
        message: message,
        logType: logType,
      );
      ggLog(yellow('Checks successful. Commit successful.'));
    } else {
      ggLog(yellow('Checks successful. Nothing to commit.'));
    }

    // Save the state
    await state.writeSuccess(
      directory: directory,
      key: stateKey,
    );
  }

  /// The state used to save the state of the command
  final GgState state;

  /// The key used to save the state of the command
  final String stateKey = 'doCommit';

  // ...........................................................................
  /// Adds and commits the current directory.
  Future<void> gitAddAndCommit({
    required Directory directory,
    required String message,
    required cl.LogType logType,
  }) async {
    await _gitAdd(directory, message);
    await _gitCommit(directory: directory, message: message, logType: logType);
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final GgProcessWrapper _processWrapper;
  final IsCommitted _isGitCommitted;
  final CanCommit _canCommit;
  final Commit _commit;
  final cl.Add _addToChangeLog;

  // ...........................................................................
  void _addParam() {
    argParser.addFlag(
      'log',
      abbr: 'l',
      help: 'Do not add message to CHANGELOG.md.',
      negatable: true,
      defaultsTo: true,
    );
  }

  // ...........................................................................
  Future<void> _gitAdd(Directory directory, String message) async {
    final result = await _processWrapper.run(
      'git',
      ['add', '.'],
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      throw Exception('git add failed: ${result.stderr}');
    }
  }

  // ...........................................................................
  /// Executes the git commit command.
  Future<void> _gitCommit({
    required Directory directory,
    required String message,
    required cl.LogType logType,
  }) async {
    const logTypeToEmoji = {
      cl.LogType.added: 'Add',
      cl.LogType.changed: 'Modify',
      cl.LogType.deprecated: 'Deprecate',
      cl.LogType.fixed: 'Fix',
      cl.LogType.removed: 'Remove',
      cl.LogType.security: 'Secure',
    };

    message = '${logTypeToEmoji[logType]}: $message';

    final result = await _processWrapper.run(
      'git',
      ['commit', '-m', message],
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      throw Exception('git commit failed: ${result.stderr}');
    }
  }

  // ...........................................................................
  /// The help text printed when type and message are missing.
  String get helpOnMissingTypeAndMessage {
    final part0 = red('Run again with type and message.\n');
    final part1 =
        blue('gg do commit ${yellow('<type>')} ${yellow('<message>')}');
    return '$part0$part1';
  }

  // ...........................................................................
  /// The help text printed when message is missing.
  String helpOnMissingMessage(cl.LogType type) {
    final typeString = _logTypes.elementAt(type.index);

    final part0 = red('Run again with message.\n');
    final part1 = blue('gg do commit $typeString ${yellow('<message>')}');
    return '$part0$part1';
  }

  // ...........................................................................
  /// The help text printed when type is invalid.
  String helpOnWrongLogType({required String wrongType}) {
    return red('Type ${red(wrongType)} is not valid. Allowed:\n') +
        _logTypes.map((e) => yellow(e)).join(' ');
  }

  // ...........................................................................
  cl.LogType _getLogTypeFromArgs(bool everythingIsCommitted) {
    if ((argResults?.rest.length ?? 0) < 1) {
      throw Exception(
        helpOnMissingTypeAndMessage,
      );
    }

    final logTypeString = argResults!.rest[0];
    try {
      return _stringToLogType(logTypeString);
    } catch (e) {
      throw Exception(
        helpOnWrongLogType(wrongType: logTypeString),
      );
    }
  }

  // ...........................................................................
  String _getMessageFromArgs(bool everythingIsCommitted, cl.LogType logType) {
    if ((argResults?.rest.length ?? 0) < 2) {
      throw Exception(helpOnMissingMessage(logType));
    }

    final message = argResults!.rest.sublist(1).join(' ');
    return message;
  }

  // ...........................................................................
  Future<String> _repositoryUrl(Directory directory) async {
    final pubspec = await File('${directory.path}/pubspec.yaml').readAsString();
    RegExp regExp = RegExp(r'^\s*repository:\s*(.+)$', multiLine: true);
    Match? match = regExp.firstMatch(pubspec);
    String? repositoryUrl = match?.group(1)?.replaceAll(RegExp(r'/$'), '');
    if (repositoryUrl == null) {
      throw Exception('No »repository:« found in pubspec.yaml');
    }
    return repositoryUrl;
  }

  // ...........................................................................
  Future<bool> _writeMessageIntoChangeLog({
    required Directory directory,
    required String message,
    required cl.LogType logType,
    required String repoUrl,
    required bool commit,
  }) async {
    // Check if message is already in CHANGELOG.md
    final changeLog =
        await File('${directory.path}/CHANGELOG.md').readAsString();

    if (changeLog.contains(message)) {
      return false;
    }

    // Remember hash before
    final hashBefore = await state.currentHash(
      directory: directory,
      ggLog: ggLog,
    );

    // Use cider to write into CHANGELOG.md
    await _addToChangeLog.exec(
      directory: directory,
      ggLog: (_) {}, // coverage:ignore-line
      message: message,
      logType: logType,
    );

    // Replace previous hash by new hash in .gg.json
    // Thus »gg can commit|push|publish« will not start from beginning
    await state.updateHash(hash: hashBefore, directory: directory);

    // If everything was committed before, commit the new changes also
    if (commit) {
      await _commit.commit(
        ggLog: (_) {}, // coverage:ignore-line
        directory: directory,
        doStage: true,
        message: message,
        ammendWhenNotPushed: true,
      );
    }

    return true;
  }
}

// .............................................................................
/// Mock for [DoCommit].
class MockDoCommmit extends Mock implements DoCommit {}
