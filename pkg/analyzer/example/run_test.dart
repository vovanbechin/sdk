// Silly hack. The Dart IntelliJ plug-in doesn't let you run a test suite as a
// normal command line app and connect to it with the debugger. So this file,
// which is outside of "test/" imports it and can be run.

import '../test/src/task/strong/nnbd_test.dart' as nnbd_test;

void main(List<String> args) {
  nnbd_test.main();
}