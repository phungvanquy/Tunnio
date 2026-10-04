import 'package:flutter/services.dart';

class WindowsLifecycle {
  static const channel = MethodChannel('com.follow.clash/lifecycle');

  Future<void> Function()? _onExit;

  Future<void> initialize(Future<void> Function() onExit) async {
    _onExit = onExit;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'requestExit') {
        throw MissingPluginException();
      }
      await _onExit?.call();
    });
    if (await channel.invokeMethod<bool>('ready') == true) {
      await _onExit?.call();
    }
  }

  void dispose() {
    _onExit = null;
    channel.setMethodCallHandler(null);
  }
}
