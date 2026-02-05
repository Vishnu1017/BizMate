import 'dart:io';

void main() {
  final file = File('pubspec.yaml');

  if (!file.existsSync()) {
    print('❌ pubspec.yaml not found');
    exit(1);
  }

  final lines = file.readAsLinesSync();
  final index = lines.indexWhere((l) => l.startsWith('version:'));

  if (index == -1) {
    print('❌ version not found in pubspec.yaml');
    exit(1);
  }

  final versionLine = lines[index].trim();
  final parts = versionLine.split('+');

  if (parts.length != 2) {
    print('❌ Invalid version format');
    exit(1);
  }

  final versionName = parts[0].replaceFirst('version:', '').trim();
  final buildNumber = int.parse(parts[1]);

  final newBuild = buildNumber + 1;
  lines[index] = 'version: $versionName+$newBuild';

  file.writeAsStringSync(lines.join('\n'));
  print('✅ Build incremented to $newBuild');
}
