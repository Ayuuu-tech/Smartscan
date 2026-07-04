import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:scanmate/core/services/auth_service.dart';

final driveServiceProvider = Provider<DriveService>((ref) => DriveService());

/// Uploads/downloads documents to the signed-in user's own Google Drive.
///
/// Uses the `drive.file` scope, so the app can only see files it created —
/// it cannot read the rest of the user's Drive. This is free (15 GB per
/// Google account) and needs the Google Drive API enabled in the project.
class DriveService {
  static const String _folderName = 'ScanMate';

  Future<drive.DriveApi?> _api() async {
    // Reuse the account from the last Google sign-in, else try a silent one.
    GoogleSignInAccount? account = AuthService.lastGoogleAccount;
    account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (account == null) return null; // not signed in with Google

    final headers = await account.authorizationClient.authorizationHeaders(
      [drive.DriveApi.driveFileScope],
      promptIfNecessary: true,
    );
    if (headers == null) return null; // Drive access not authorized

    return drive.DriveApi(_AuthClient(headers));
  }

  /// Uploads [file] as [filename] into the app's Drive folder.
  /// Returns the Drive file id, or null if it could not be uploaded.
  Future<String?> uploadPdf(File file, String filename) async {
    try {
      final api = await _api();
      if (api == null) return null;

      final folderId = await _ensureFolder(api);
      final existingId = await _findFile(api, filename, folderId);

      final media = drive.Media(file.openRead(), file.lengthSync());
      final meta = drive.File()..name = filename;

      final drive.File result;
      if (existingId != null) {
        // overwrite the previous version
        result = await api.files.update(meta, existingId, uploadMedia: media);
      } else {
        meta.parents = [folderId];
        result = await api.files.create(meta, uploadMedia: media);
      }
      return result.id;
    } catch (e) {
      debugPrint('Drive upload failed: $e');
      return null;
    }
  }

  /// Downloads a Drive file by id into [target]. Returns true on success.
  Future<bool> downloadFile(String fileId, File target) async {
    try {
      final api = await _api();
      if (api == null) return false;

      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final sink = target.openWrite();
      await media.stream.pipe(sink);
      await sink.close();
      return true;
    } catch (e) {
      debugPrint('Drive download failed: $e');
      return false;
    }
  }

  Future<String> _ensureFolder(drive.DriveApi api) async {
    final existing = await api.files.list(
      q: "name = '$_folderName' and "
          "mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (existing.files != null && existing.files!.isNotEmpty) {
      return existing.files!.first.id!;
    }
    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }

  Future<String?> _findFile(
      drive.DriveApi api, String filename, String folderId) async {
    final res = await api.files.list(
      q: "name = '$filename' and '$folderId' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id;
    }
    return null;
  }
}

/// http client that injects the Google auth headers on every request.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
