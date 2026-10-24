// lib/services/drive_backup_service.dart
// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Sign-In Response with detailed diagnostics
// ─────────────────────────────────────────────────────────────────────────────
class DriveSignInResponse {
  final GoogleSignInAccount? account;
  final String? errorMessage;
  final bool isCanceled;
  final bool isMissingPlugin;
  final bool isDeveloperError; // Google Cloud Console / Firebase OAuth misconfiguration (Code 10)
  final bool isNetworkError;

  DriveSignInResponse({
    this.account,
    this.errorMessage,
    this.isCanceled = false,
    this.isMissingPlugin = false,
    this.isDeveloperError = false,
    this.isNetworkError = false,
  });

  bool get isSuccess => account != null;

  String get friendlyMessage {
    if (isDeveloperError) {
      return 'Google Cloud OAuth error (Code 10: Missing SHA-1 fingerprint).';
    }
    if (isMissingPlugin) {
      return 'Full app restart required to initialize native Google plugins.';
    }
    if (isNetworkError) {
      return 'Network error connecting to Google. Please check your internet connection.';
    }
    if (isCanceled) {
      return 'Google Sign-In was canceled.';
    }
    return errorMessage ?? 'Failed to connect to Google Drive.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Authenticated HTTP client for googleapis with dynamic token refresh
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleAuthClient extends http.BaseClient {
  final GoogleSignInAccount _account;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._account);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _account.authHeaders;
    return _client.send(request..headers.addAll(headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drive Backup Service
// ─────────────────────────────────────────────────────────────────────────────
class DriveBackupService {
  static const String _folderName = 'BizMate Backups';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  static bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Sign in with full diagnostic response for the UI
  static Future<DriveSignInResponse> signInDetailed() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return DriveSignInResponse(isCanceled: true);
      }
      return DriveSignInResponse(account: account);
    } catch (e) {
      final msg = e.toString();
      debugPrint('DriveBackupService.signIn error: $msg');
      final isMissing = msg.contains('MissingPluginException') ||
          msg.contains('channel-error') ||
          msg.contains('Unable to establish connection on channel');
      final isDevErr = msg.contains('ApiException: 10') ||
          msg.contains('status code: 10') ||
          msg.contains('DEVELOPER_ERROR') ||
          msg.contains('10:');
      final isNet = msg.contains('ApiException: 7') ||
          msg.contains('NETWORK_ERROR') ||
          msg.contains('SocketException');
      return DriveSignInResponse(
        errorMessage: msg,
        isMissingPlugin: isMissing,
        isDeveloperError: isDevErr,
        isNetworkError: isNet,
      );
    }
  }

  /// Sign in returning account (or null on failure/cancel)
  static Future<GoogleSignInAccount?> signIn() async {
    final resp = await signInDetailed();
    return resp.account;
  }

  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('DriveBackupService.signInSilently error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('DriveBackupService.signOut error: $e');
    }
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    var account = _googleSignIn.currentUser;
    if (account == null) {
      try {
        account = await _googleSignIn.signInSilently();
      } catch (e) {
        debugPrint('DriveBackupService._getDriveApi silent sign-in failed: $e');
      }
    }
    if (account == null) return null;
    final client = _GoogleAuthClient(account);
    return drive.DriveApi(client);
  }

  static Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    try {
      final result = await api.files.list(
        q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
        spaces: 'drive',
        $fields: 'files(id, name)',
      );
      if (result.files != null && result.files!.isNotEmpty) {
        return result.files!.first.id;
      }
      final folder = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';
      final created = await api.files.create(folder);
      return created.id;
    } catch (e) {
      debugPrint('DriveBackupService._getOrCreateFolder error: $e');
      return null;
    }
  }

  /// Upload a local backup file to Drive. Returns Drive file ID or null.
  static Future<String?> uploadBackupFile(File file) async {
    try {
      var api = await _getDriveApi();
      if (api == null) {
        final acc = await signIn();
        if (acc != null) {
          api = await _getDriveApi();
        }
      }
      if (api == null) {
        debugPrint('DriveBackupService: Not signed in, cannot upload.');
        return null;
      }

      final folderId = await _getOrCreateFolder(api);
      final fileName = file.path.split(Platform.pathSeparator).last;
      final fileSize = await file.length();

      final driveFile = drive.File()
        ..name = fileName
        ..mimeType = 'application/json'
        ..description = 'BizMate business data backup';

      if (folderId != null && folderId.isNotEmpty) {
        driveFile.parents = [folderId];
      }

      final media = drive.Media(
        file.openRead(),
        fileSize,
        contentType: 'application/json',
      );

      final result = await api.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, size, createdTime',
      );
      debugPrint('DriveBackupService: Uploaded file to Drive successfully: ${result.id}');
      return result.id;
    } catch (e) {
      debugPrint('DriveBackupService uploadBackupFile error: $e');
      return null;
    }
  }

  static Future<List<DriveBackupFile>> listDriveBackups() async {
    try {
      var api = await _getDriveApi();
      if (api == null) {
        final acc = await signInSilently();
        if (acc != null) {
          api = await _getDriveApi();
        }
      }
      if (api == null) {
        debugPrint('DriveBackupService.listDriveBackups: No DriveApi client available.');
        return [];
      }

      final Set<String> seenIds = {};
      final List<DriveBackupFile> backups = [];

      // 1. Search inside all folders named 'BizMate Backups'
      try {
        final folderList = await api.files.list(
          q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
          spaces: 'drive',
          $fields: 'files(id, name)',
        );
        final folders = folderList.files ?? [];
        for (final folder in folders) {
          if (folder.id != null && folder.id!.isNotEmpty) {
            try {
              final res = await api.files.list(
                q: "'${folder.id}' in parents and trashed=false",
                orderBy: 'createdTime desc',
                spaces: 'drive',
                $fields: 'files(id, name, size, createdTime)',
              );
              for (final f in (res.files ?? [])) {
                if (f.id != null && !seenIds.contains(f.id)) {
                  seenIds.add(f.id!);
                  backups.add(DriveBackupFile(
                    id: f.id!,
                    name: f.name ?? 'BizMate_Backup.json',
                    sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
                    createdAt: f.createdTime ?? DateTime.now(),
                  ));
                }
              }
            } catch (e) {
              debugPrint('DriveBackupService folder query error: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('DriveBackupService folder list error: $e');
      }

      // 2. Broad search across Drive for any BizMate or backup json files
      try {
        final broadRes = await api.files.list(
          q: "trashed=false and (name contains 'BizMate' or name contains 'bizmate' or name contains 'Backup')",
          orderBy: 'createdTime desc',
          spaces: 'drive',
          $fields: 'files(id, name, size, createdTime)',
        );
        for (final f in (broadRes.files ?? [])) {
          if (f.id != null && !seenIds.contains(f.id)) {
            final name = (f.name ?? '').toLowerCase();
            if (name.endsWith('.json') || name.contains('bizmate')) {
              seenIds.add(f.id!);
              backups.add(DriveBackupFile(
                id: f.id!,
                name: f.name ?? 'BizMate_Backup.json',
                sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
                createdAt: f.createdTime ?? DateTime.now(),
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('DriveBackupService broad query error: $e');
      }

      // Sort by newest first
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      debugPrint('DriveBackupService: Found ${backups.length} Drive backup file(s)');
      return backups;
    } catch (e) {
      debugPrint('DriveBackupService listDriveBackups error: $e');
      return [];
    }
  }

  static Future<bool> deleteDriveBackup(String fileId) async {
    try {
      final api = await _getDriveApi();
      if (api == null) return false;
      await api.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('DriveBackupService deleteDriveBackup error: $e');
      return false;
    }
  }

  /// Download a backup file from Google Drive to local destination file.
  static Future<File?> downloadBackupFile(
    String fileId,
    File destinationFile,
  ) async {
    try {
      var api = await _getDriveApi();
      if (api == null) {
        debugPrint('DriveBackupService.downloadBackupFile: DriveApi was null, trying silent sign-in');
        final acc = await signInSilently();
        if (acc != null) {
          api = await _getDriveApi();
        }
      }
      if (api == null) {
        debugPrint('DriveBackupService.downloadBackupFile: Failed to get DriveApi');
        return null;
      }

      debugPrint('DriveBackupService.downloadBackupFile: Requesting file ID: $fileId');
      final response = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        if (await destinationFile.exists()) {
          await destinationFile.delete();
        }
        
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
        }
        await destinationFile.writeAsBytes(bytes, flush: true);

        final length = await destinationFile.length();
        debugPrint('DriveBackupService.downloadBackupFile: Downloaded $length bytes');
        if (length > 0) {
          return destinationFile;
        }
      } else {
        debugPrint('DriveBackupService.downloadBackupFile: Response is not Media (${response.runtimeType})');
      }
      return null;
    } catch (e, st) {
      debugPrint('DriveBackupService downloadBackupFile error: $e\n$st');
      return null;
    }
  }
}

class DriveBackupFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;

  DriveBackupFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
  });

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
