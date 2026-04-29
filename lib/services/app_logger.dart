import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    filter: DevelopmentFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 90,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void debug(String message, {Object? data}) {
    if (kDebugMode) {
      _logger.d(_format(message, data));
    }
  }

  static void info(String message, {Object? data}) {
    if (kDebugMode) {
      _logger.i(_format(message, data));
    }
  }

  static void warning(
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _logger.w(_format(message, data), error: error, stackTrace: stackTrace);
    }
  }

  static void error(
    String message, {
    Object? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _logger.e(_format(message, data), error: error, stackTrace: stackTrace);
    }
  }

  static String _format(String message, Object? data) {
    if (data == null) {
      return message;
    }
    return '$message | $data';
  }
}
