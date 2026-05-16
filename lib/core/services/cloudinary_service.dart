import 'dart:convert';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shop/core/config/cloudinary_config.dart';
import 'package:shop/models/cloudinary_image_ref.dart';

class CloudinaryService {
  const CloudinaryService();

  bool get isConfigured => CloudinaryConfig.isConfigured;
  bool get canDeleteRemotely => CloudinaryConfig.canDeleteRemotely;

  Future<String> uploadProductImage(XFile file) async {
    return uploadImageFile(file, folder: CloudinaryConfig.uploadFolder);
  }

  Future<String> uploadCategoryImage(XFile file) async {
    return uploadImageFile(
      file,
      folder: '${CloudinaryConfig.uploadFolder}/categories',
    );
  }

  Future<String> uploadBannerImage(XFile file) async {
    return uploadImageFile(
      file,
      folder: '${CloudinaryConfig.uploadFolder}/home_banners',
    );
  }

  Future<String> uploadAssetCategoryImage(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();
    final fileName = _fileNameFromPath(assetPath);
    return uploadImageBytes(
      bytes: bytes,
      fileName: fileName,
      folder: '${CloudinaryConfig.uploadFolder}/categories',
      publicId: _publicIdFromName(fileName),
    );
  }

  Future<String> uploadImageFile(
    XFile file, {
    required String folder,
    String? publicId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Cloudinary is not configured. Add your cloud name and unsigned '
        'upload preset in lib/core/config/cloudinary_config.dart.',
      );
    }

    final compressedBytes = await _compressImage(await file.readAsBytes());
    return uploadImageBytes(
      bytes: compressedBytes,
      fileName: file.name,
      folder: folder,
      publicId: publicId,
    );
  }

  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String fileName,
    required String folder,
    String? publicId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Cloudinary is not configured. Add your cloud name and unsigned '
        'upload preset in lib/core/config/cloudinary_config.dart.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.unsignedUploadPreset
      ..fields['folder'] = folder
      ..fields['quality'] = 'auto:good'
      ..fields['fetch_format'] = 'auto';

    if ((publicId ?? '').trim().isNotEmpty) {
      request.fields['public_id'] = publicId!.trim();
      request.fields['overwrite'] = 'true';
    }

    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    return _sendRequest(request);
  }

  Future<void> deleteImageByUrl(String? secureUrl, {String? publicId}) async {
    final ref = imageRefFromUrl(secureUrl, publicId: publicId);
    if (ref == null) {
      return;
    }
    await deleteImage(ref);
  }

  Future<void> deleteImagesByUrls(
    Iterable<String?> secureUrls, {
    Iterable<String?> publicIds = const <String?>[],
  }) async {
    final refs = <CloudinaryImageRef>[];
    final publicIdList = publicIds.toList(growable: false);
    var index = 0;
    for (final url in secureUrls) {
      final ref = imageRefFromUrl(
        url,
        publicId: index < publicIdList.length ? publicIdList[index] : null,
      );
      if (ref != null) {
        refs.add(ref);
      }
      index += 1;
    }
    await deleteImages(refs);
  }

  Future<void> deleteImages(Iterable<CloudinaryImageRef> refs) async {
    for (final ref in refs) {
      await deleteImage(ref);
    }
  }

  Future<void> deleteImage(CloudinaryImageRef ref) async {
    if (!canDeleteRemotely) {
      // Deletion is intentionally disabled on the client.
      // Wire up a Firebase Cloud Function to handle signed Cloudinary deletes.
      return;
    }
  }

  CloudinaryImageRef? imageRefFromUrl(String? secureUrl, {String? publicId}) {
    final normalizedUrl = (secureUrl ?? '').trim();
    final normalizedPublicId =
        (publicId ?? _extractPublicIdFromUrl(normalizedUrl)).trim();
    if (normalizedUrl.isEmpty && normalizedPublicId.isEmpty) {
      return null;
    }
    return CloudinaryImageRef(
      secureUrl: normalizedUrl,
      publicId: normalizedPublicId.isEmpty ? null : normalizedPublicId,
    );
  }

  Future<String> _sendRequest(http.MultipartRequest request) async {
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['error'] is Map<String, dynamic>
            ? (data['error']['message'] as String? ??
                  'Cloudinary upload failed.')
            : 'Cloudinary upload failed.',
      );
    }

    return data['secure_url'] as String? ?? '';
  }

  String _fileNameFromPath(String path) {
    final segments = path.split('/');
    return segments.isEmpty ? path : segments.last;
  }

  String _publicIdFromName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final noExt = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    return noExt
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 76,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty) {
        return Uint8List.fromList(compressed);
      }
    } catch (_) {
      // Fall back to original bytes if compression fails on any platform.
    }
    return bytes;
  }

  String _extractPublicIdFromUrl(String secureUrl) {
    if (secureUrl.isEmpty || !secureUrl.contains('/upload/')) {
      return '';
    }

    final uri = Uri.tryParse(secureUrl);
    if (uri == null) {
      return '';
    }

    final uploadIndex = uri.pathSegments.indexOf('upload');
    if (uploadIndex == -1 || uploadIndex + 1 >= uri.pathSegments.length) {
      return '';
    }

    final tailSegments = uri.pathSegments.skip(uploadIndex + 1).toList();
    final versionIndex = tailSegments.indexWhere(
      (segment) =>
          segment.startsWith('v') && int.tryParse(segment.substring(1)) != null,
    );
    final publicIdSegments = versionIndex >= 0
        ? tailSegments.skip(versionIndex + 1).toList()
        : tailSegments.where((segment) => !_looksLikeTransformation(segment)).toList();

    if (publicIdSegments.isEmpty && tailSegments.isNotEmpty) {
      publicIdSegments.addAll(tailSegments.skip(1));
    }

    if (publicIdSegments.isEmpty) {
      return '';
    }

    final last = publicIdSegments.removeLast();
    final dotIndex = last.lastIndexOf('.');
    publicIdSegments.add(dotIndex == -1 ? last : last.substring(0, dotIndex));
    return publicIdSegments.join('/');
  }

  bool _looksLikeTransformation(String segment) {
    return segment.contains(',');
  }
}
