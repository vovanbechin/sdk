import 'dart:io';

import 'package:path/path.dart' as p;

// Analyzes the SDK core libraries for errors.
//
// Yes, this is a super hacky way to do it. It's a prototype.

final repoDir = p.normalize(p.join(p.fromUri(Platform.script), '../../../../'));
final sdkDirPattern = new RegExp(".*/dart-sdk/lib/(.*)");

main(List<String> args) {
  print("Analyzing SDK...");
  var result = Process.runSync("dart", [
    p.join(repoDir, 'pkg/analyzer_cli/bin/analyzer.dart'),
    '--strong',
    '--warnings',
    '--no-hints',
    '--machine',
    p.join(repoDir, 'pkg/analyzer/tool/empty.dart')
  ]);

  var lines = (result.stderr as String).split('\n');
  var errors = <String>[];

  for (var line in lines) {
    if (line.trim().isEmpty) continue;

    var fields = line.split('|');
    if (fields[0] != 'ERROR') continue;

    var libraryPath = sdkDirPattern.firstMatch(fields[3]).group(1);
    var error = "$libraryPath ${fields[4]}:${fields[5]}-${fields[6]}: ${fields[7]}";
    print(error);
    errors.add(error);
  }

  errors.sort();

  var file = new File(p.join(repoDir, 'pkg/analyzer/tool/sdk_errors.txt'));
  file.writeAsStringSync(errors.join('\n'));

  print("${errors.length} total errors.");
}
