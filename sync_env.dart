import 'dart:io';

void main(List<String> args) {
  final envPath = args.isNotEmpty ? args.first : '.env';
  final envFile = File(envPath);

  if (!envFile.existsSync()) {
    stderr.writeln('Missing $envPath. Create it from .env.example first.');
    exitCode = 1;
    return;
  }

  final env = _parseEnv(envFile.readAsStringSync());

  final sharedKey = _readFirst(env, ['MAPS_API_KEY']);
  final androidKey = _readFirst(env, ['MAPS_API_KEY_ANDROID']) ?? sharedKey;
  final iosKey = _readFirst(env, ['MAPS_API_KEY_IOS']) ?? sharedKey;
  final webKey = _readFirst(env, ['MAPS_API_KEY_WEB']) ?? sharedKey;

  if ((androidKey ?? '').isEmpty || (iosKey ?? '').isEmpty || (webKey ?? '').isEmpty) {
    stderr.writeln(
      'Missing map keys in .env. Set MAPS_API_KEY or all of MAPS_API_KEY_ANDROID, MAPS_API_KEY_IOS, MAPS_API_KEY_WEB.',
    );
    exitCode = 1;
    return;
  }

  _syncAndroidLocalProperties(androidKey!);
  _syncIosInfoPlist(iosKey!);
  _syncWebIndexHtml(webKey!);

  stdout.writeln('Environment sync completed.');
  stdout.writeln('Updated: android/local.properties, ios/Runner/Info.plist, web/index.html');
}

Map<String, String> _parseEnv(String raw) {
  final result = <String, String>{};
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final index = trimmed.indexOf('=');
    if (index <= 0) {
      continue;
    }
    final key = trimmed.substring(0, index).trim();
    var value = trimmed.substring(index + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

String? _readFirst(Map<String, String> env, List<String> keys) {
  for (final key in keys) {
    final value = env[key]?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

void _syncAndroidLocalProperties(String apiKey) {
  final file = File('android/local.properties');
  if (!file.existsSync()) {
    throw Exception('android/local.properties not found.');
  }

  final lines = file.readAsLinesSync();
  var found = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('MAPS_API_KEY=')) {
      lines[i] = 'MAPS_API_KEY=$apiKey';
      found = true;
      break;
    }
  }
  if (!found) {
    lines.add('MAPS_API_KEY=$apiKey');
  }

  file.writeAsStringSync('${lines.join('\n')}\n');
}

void _syncIosInfoPlist(String apiKey) {
  final file = File('ios/Runner/Info.plist');
  if (!file.existsSync()) {
    throw Exception('ios/Runner/Info.plist not found.');
  }

  final content = file.readAsStringSync();
  final keyPattern = RegExp(r'<key>GMSApiKey</key>\s*<string>.*?</string>', dotAll: true);

  final replacement = '<key>GMSApiKey</key>\n\t<string>$apiKey</string>';

  String updated;
  if (keyPattern.hasMatch(content)) {
    updated = content.replaceFirst(keyPattern, replacement);
  } else {
    updated = content.replaceFirst('</dict>', '\t$replacement\n</dict>');
  }

  file.writeAsStringSync(updated);
}

void _syncWebIndexHtml(String apiKey) {
  final file = File('web/index.html');
  if (!file.existsSync()) {
    throw Exception('web/index.html not found.');
  }

  final content = file.readAsStringSync();
  final scriptPattern = RegExp(
    r'<script\s+src="https://maps.googleapis.com/maps/api/js\?key=[^"]*"\s*></script>',
    caseSensitive: false,
  );

  final newScript = '  <script src="https://maps.googleapis.com/maps/api/js?key=$apiKey"></script>';

  String updated;
  if (scriptPattern.hasMatch(content)) {
    updated = content.replaceFirst(scriptPattern, newScript);
  } else {
    updated = content.replaceFirst('</head>', '$newScript\n</head>');
  }

  file.writeAsStringSync(updated);
}
