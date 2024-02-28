// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:colorize/colorize.dart';
import 'package:gg_check/src/tools/base_cmd.dart';
import 'package:gg_check/src/tools/run_process.dart';

/// Pana
class Pana extends Command<dynamic> {
  /// Constructor
  Pana({
    required this.log,
    this.runProcess = Process.run,
  });

  // ...........................................................................
  @override
  final name = 'pana';
  @override
  final description = 'Runs pana.';

  /// Example instance for test purposes
  factory Pana.example({
    void Function(String msg)? log,
    bool exitOnError = false,
    RunProcess? runProcess,
  }) =>
      Pana(
        log: log ?? (_) {}, // coverage:ignore-line
        runProcess: runProcess ?? Process.run,
      );

  @override
  Future<void> run() async {
    // coverage:ignore-start
    await BaseCmd(
      name: 'pana',
      task: _task,
      message: 'gg_check pana',
      log: log,
    ).run();
    // coverage:ignore-end
  }

  /// The log function
  final void Function(String message) log;

  /// The process run method
  final RunProcess runProcess;

  // ...........................................................................
  List<String> _readProblems(Map<String, dynamic> jsonOutput) {
    final problems = <String>[];
    final sections = jsonOutput['report']['sections'] as List<dynamic>;
    final failedSections =
        sections.where((section) => section['status'] == 'failed');

    for (final section in failedSections) {
      final summary = section['summary'] as String;
      final errorPoints = summary.split('###').where(
            (element) => element.contains('[x]'),
          );

      for (final errorPoint in errorPoints) {
        final parts = errorPoint.split('\n').map(
              (e) => e.trim(),
            );

        final title = parts.first;
        final details = parts.skip(1);

        final titleRed = Colorize(title).red().toString();
        final detailsGray = details
            .map(
              (e) => Colorize(e).darkGray().toString(),
            )
            .join('\n');
        problems.add('\n$titleRed$detailsGray');
      }
    }
    return problems;
  }

// ...........................................................................
  Future<TaskResult> _task() async {
    // Run 'pana' and capture the output
    final result = await runProcess('dart', [
      'run',
      'pana',
      '--no-warning',
      '--json',
      '--no-dartdoc', // dartdoc is enforced using analysis_options.yaml
    ]);

    try {
      // Parse the JSON output to get the score
      final jsonOutput =
          jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
      final grantedPoints = jsonOutput['scores']['grantedPoints'];
      final maxPoints = jsonOutput['scores']['maxPoints'];
      final complete = grantedPoints == maxPoints;
      final points = '$grantedPoints/$maxPoints';

      // Check if the score is less than 140
      if (!complete) {
        final errors = _readProblems(jsonOutput);

        return (1, <String>[], errors);
      } else {
        final messages = [
          'All pub points achieved: $points',
        ];
        return (0, <String>[], messages);
      }
    } catch (e) {
      return (1, ['Error parsing pana output: $e'], <String>[]);
    }
  }
}
