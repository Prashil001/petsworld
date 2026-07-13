import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> saveOrderExportFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final directory = await _resolveDownloadDirectory();
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory> _resolveDownloadDirectory() async {
  if (Platform.isIOS) {
    final appDirectory = await getApplicationDocumentsDirectory();
    return Directory('${appDirectory.path}${Platform.pathSeparator}petsworld');
  }

  final downloadsDirectory = await getDownloadsDirectory();
  if (downloadsDirectory != null) {
    return Directory(
      '${downloadsDirectory.path}${Platform.pathSeparator}petsworld',
    );
  }

  final externalDirectories = await getExternalStorageDirectories(
    type: StorageDirectory.downloads,
  );
  if (externalDirectories != null && externalDirectories.isNotEmpty) {
    return Directory(
      '${externalDirectories.first.path}${Platform.pathSeparator}petsworld',
    );
  }

  final appDirectory = await getApplicationDocumentsDirectory();
  return Directory('${appDirectory.path}${Platform.pathSeparator}petsworld');
}
