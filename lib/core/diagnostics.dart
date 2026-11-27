import 'dart:developer' as developer;

class Diagnostics {
  const Diagnostics();

  void failure(String operation, Object error) {
    developer.log('$operation failed (${error.runtimeType})', name: 'optiq');
  }

  Future<T> measure<T>(String operation, Future<T> Function() run) async {
    final task = developer.TimelineTask()..start(operation);
    final timer = Stopwatch()..start();
    try {
      return await run();
    } catch (error) {
      failure(operation, error);
      rethrow;
    } finally {
      task.finish(arguments: {'elapsedMs': timer.elapsedMilliseconds});
    }
  }
}
