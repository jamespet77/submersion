import 'dart:convert';
import 'dart:io';

/// Completed-process result (a dart:io-free mirror of ProcessResult so
/// fakes need no dart:io types).
class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Injectable seam over dart:io Process so engines are unit-testable
/// without external binaries.
abstract class TranscoderProcessRunner {
  Future<ProcessRunResult> run(String executable, List<String> arguments);

  /// Starts the process, forwarding each stdout line, and returns the exit
  /// code. Stderr is collected internally by implementations for error text.
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  });
}

class SystemProcessRunner implements TranscoderProcessRunner {
  /// Stderr of the last [stream] call, for error messages.
  String lastStderr = '';

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await Process.run(executable, arguments);
      return ProcessRunResult(
        exitCode: result.exitCode,
        stdout: result.stdout as String,
        stderr: result.stderr as String,
      );
    } on ProcessException catch (e) {
      return ProcessRunResult(exitCode: 127, stdout: '', stderr: e.message);
    }
  }

  @override
  Future<int> stream(
    String executable,
    List<String> arguments, {
    void Function(String line)? onStdoutLine,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException catch (e) {
      lastStderr = e.message;
      return 127;
    }
    final stderrBuf = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => onStdoutLine?.call(line));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuf.write);
    final code = await process.exitCode;
    await stdoutDone;
    await stderrDone;
    lastStderr = stderrBuf.toString();
    return code;
  }
}
