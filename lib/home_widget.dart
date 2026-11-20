import 'storage/platform_native.dart'
    if (dart.library.js_interop) 'storage/platform_web.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The launcher renders native RemoteViews and writes the same SQLite journal.
class HomeWidgetService {
  HomeWidgetService({MethodChannel? channel, bool? supported})
    : channel = channel ?? const MethodChannel('qada_tracker/home_widget'),
      supported = supported ?? androidSupported {
    if (this.supported) {
      this.channel.setMethodCallHandler((call) async {
        if (call.method == 'journalChanged') await onJournalChanged?.call();
      });
    }
  }
  final MethodChannel channel;
  final bool supported;
  Future<void> Function()? onJournalChanged;

  Future<void> sync() async {
    if (!supported) return;
    try {
      await channel.invokeMethod<void>('sync');
    } on PlatformException {
      // The journal is already saved. A launcher refresh may be retried on
      // resume, periodic update, or the next tap; never undo a saved record.
    } on MissingPluginException {
      // Widget support is Android-only and optional on older installations.
    }
  }

  Future<bool> requestPin() async {
    if (!supported) return false;
    try {
      return await channel.invokeMethod<bool>('requestPin') == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final homeWidgetServiceProvider = Provider<HomeWidgetService>(
  (ref) => HomeWidgetService(),
);
