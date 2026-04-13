import 'package:flutter/services.dart';

/// Opens http(s) URLs via the same native [MethodChannel] as [PermissionService]
/// (`io.lumio.app/permissions`), so URL opening uses a channel that is already
/// wired in [MainActivity] / [AppDelegate].
class ExternalUrlService {
  ExternalUrlService._();

  static const MethodChannel _channel = MethodChannel('io.lumio.app/permissions');

  static Future<void> openUrl(String url) async {
    await _channel.invokeMethod<void>('openExternalUrl', url);
  }
}
