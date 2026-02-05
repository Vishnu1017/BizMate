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

  final raw = lines[index].replaceFirst('version:', '').trim();
  final parts = raw.split('+');

  if (parts.length != 2) {
    print('❌ Invalid version format');
    exit(1);
  }

  // Parse version
  final versionParts = parts[0].split('.').map(int.parse).toList();
  int major = versionParts[0];
  int minor = versionParts[1];
  int patch = versionParts[2];

  // AUTO PATCH BUMP
  patch += 1;

  // AUTO BUILD BUMP
  final build = int.parse(parts[1]) + 1;

  final newVersion = '$major.$minor.$patch+$build';
  lines[index] = 'version: $newVersion';

  file.writeAsStringSync(lines.join('\n'));

  print('🚀 Version updated to $newVersion');
}
