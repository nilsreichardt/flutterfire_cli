/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import 'dart:io';

import 'package:ansi_styles/ansi_styles.dart';
import 'package:path/path.dart';

import '../common/strings.dart';
import '../common/utils.dart';
import 'firebase_options.dart';

class FirebaseConfigurationFile {
  FirebaseConfigurationFile(
    this.outputFilePath, {
    this.androidOptions,
    this.iosOptions,
    this.macosOptions,
    this.webOptions,
    this.windowsOptions,
    this.linuxOptions,
    this.overwriteFirebaseOptions,
    this.force = false,
  });

  final StringBuffer _stringBuffer = StringBuffer();

  final String outputFilePath;

  /// Whether to skip prompts and force write output file.
  final bool force;

  final bool? overwriteFirebaseOptions;

  FirebaseOptions? webOptions;

  FirebaseOptions? macosOptions;

  FirebaseOptions? androidOptions;

  FirebaseOptions? iosOptions;

  FirebaseOptions? windowsOptions;

  FirebaseOptions? linuxOptions;

  Future<void> write() async {
    final outputFile = File(joinAll([Directory.current.path, outputFilePath]));
    final fileExists = outputFile.existsSync();

    // If the user specifically chooses to negate overwriting the file, return immediately
    if (fileExists && overwriteFirebaseOptions == false) return;

    // Write buffer early so we can string compare contents if file exists already.
    _writeHeader();
    _writeClass();
    final newFileContents = _stringBuffer.toString();

    if (fileExists && !force) {
      final existingFileContents = await outputFile.readAsString();
      // Only prompt overwrite if contents have changed.
      // Trimming since some IDEs/git auto apply a trailing newline.
      if (existingFileContents.trim() != newFileContents.trim()) {
        // If the user chooses this option, they want it overwritten so no need to prompt
        if (overwriteFirebaseOptions != true) {
          final shouldOverwrite = promptBool(
            'Generated FirebaseOptions file ${AnsiStyles.cyan(outputFilePath)} already exists, do you want to override it?',
          );
          if (!shouldOverwrite) {
            throw FirebaseOptionsAlreadyExistsException(outputFilePath);
          }
        }
      }
    }

    outputFile.createSync(recursive: true);
    outputFile.writeAsStringSync(_stringBuffer.toString());
  }

  void _writeHeader() {
    _stringBuffer.writeAll(
      <String>[
        '// File generated by FlutterFire CLI.',
        '// ignore_for_file: type=lint',
        "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;",
        "import 'package:flutter/foundation.dart'",
        '    show defaultTargetPlatform, kIsWeb, TargetPlatform;',
        '',
        '/// Default [FirebaseOptions] for use with your Firebase apps.',
        '///',
        '/// Example:',
        '/// ```dart',
        "/// import '${basename(outputFilePath)}';",
        '/// // ...',
        '/// await Firebase.initializeApp(',
        '///   options: DefaultFirebaseOptions.currentPlatform,',
        '/// );',
        '/// ```',
        '',
      ],
      '\n',
    );
  }

  void _writeClass() {
    _stringBuffer.writeAll(
      <String>[
        'class DefaultFirebaseOptions {',
        '  static FirebaseOptions get currentPlatform {',
        ''
      ],
      '\n',
    );
    _writeCurrentPlatformWeb();
    _stringBuffer.writeln('    switch (defaultTargetPlatform) {');
    _writeCurrentPlatformSwitchAndroid();
    _writeCurrentPlatformSwitchIos();
    _writeCurrentPlatformSwitchMacos();
    _writeCurrentPlatformSwitchWindows();
    _writeCurrentPlatformSwitchLinux();
    _stringBuffer.write(
      '''
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
''',
    );
    _writeFirebaseOptionsStatic(kWeb, webOptions);
    _writeFirebaseOptionsStatic(kAndroid, androidOptions);
    _writeFirebaseOptionsStatic(kIos, iosOptions);
    _writeFirebaseOptionsStatic(kMacos, macosOptions);
    _writeFirebaseOptionsStatic(kWindows, windowsOptions);
    _writeFirebaseOptionsStatic(kLinux, linuxOptions);
    _stringBuffer.writeln('}'); // } DefaultFirebaseOptions
  }

  void _writeFirebaseOptionsStatic(String platform, FirebaseOptions? options) {
    if (options == null) return;
    _stringBuffer.writeAll(
      <String>[
        '',
        '  static const FirebaseOptions $platform = FirebaseOptions(',
        ...options.asMap.entries
            .where((entry) => entry.value != null)
            .map((entry) => "    ${entry.key}: '${entry.value}',"),
        '  );', // FirebaseOptions
        '',
      ],
      '\n',
    );
  }

  void _writeThrowUnsupportedForPlatform(String platform, String indentation) {
    _stringBuffer.writeAll(
      <String>[
        '${indentation}throw UnsupportedError(',
        "$indentation  'DefaultFirebaseOptions have not been configured for $platform - '",
        "$indentation  'you can reconfigure this by running the FlutterFire CLI again.',",
        '$indentation);',
        '',
      ],
      '\n',
    );
  }

  void _writeCurrentPlatformWeb() {
    _stringBuffer.writeln('    if (kIsWeb) {');
    if (webOptions != null) {
      _stringBuffer.writeln('      return web;');
    } else {
      _writeThrowUnsupportedForPlatform(kWeb, '      ');
    }
    _stringBuffer.writeln('    }');
  }

  void _writeCurrentPlatformSwitchAndroid() {
    _stringBuffer.writeln('      case TargetPlatform.android:');
    if (androidOptions != null) {
      _stringBuffer.writeln('        return android;');
    } else {
      _writeThrowUnsupportedForPlatform(kAndroid, '        ');
    }
  }

  void _writeCurrentPlatformSwitchIos() {
    _stringBuffer.writeln('      case TargetPlatform.iOS:');
    if (iosOptions != null) {
      _stringBuffer.writeln('        return ios;');
    } else {
      _writeThrowUnsupportedForPlatform(kIos, '        ');
    }
  }

  void _writeCurrentPlatformSwitchMacos() {
    _stringBuffer.writeln('      case TargetPlatform.macOS:');
    if (macosOptions != null) {
      _stringBuffer.writeln('        return macos;');
    } else {
      _writeThrowUnsupportedForPlatform(kMacos, '        ');
    }
  }

  void _writeCurrentPlatformSwitchWindows() {
    _stringBuffer.writeln('      case TargetPlatform.windows:');
    if (windowsOptions != null) {
      _stringBuffer.writeln('        return windows;');
    } else {
      _writeThrowUnsupportedForPlatform(kWindows, '        ');
    }
  }

  void _writeCurrentPlatformSwitchLinux() {
    _stringBuffer.writeln('      case TargetPlatform.linux:');
    if (linuxOptions != null) {
      _stringBuffer.writeln('        return linux;');
    } else {
      _writeThrowUnsupportedForPlatform(kLinux, '        ');
    }
  }
}
