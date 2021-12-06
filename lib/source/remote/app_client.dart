import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlbrite/sqlbrite.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

Future<Database> _openDb() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = join(directory.path, 'database.db');
  return await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) {},
  );
}

class AppClient {
  static const _initializeSubscriberUrl =
      'http://gusrix.software/api/sync/initializeSubscriber/';
  static final shared = AppClient._(
      http.Client(),
      _openDb().then(
            (value) => BriteDatabase(value, logger: debugPrint),
      ));
  final http.Client _client;
  final Future<BriteDatabase> _db;

  AppClient._(this._client, this._db);

  Future<Map<String, String>> _getSqlCommands(String deviceUUID) async {
    final response = await _client.get(
        Uri.parse(_initializeSubscriberUrl + deviceUUID));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
          'code: ${response.statusCode}, body: ${response.body}',
          uri: response.request?.url);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (!identical(decoded['success'], true)) {
      throw HttpException(
        (decoded['message'] as String?) ?? 'Failed request: ${response.body}',
        uri: response.request?.url,
      );
    }
    return Map<String, String>.from(jsonDecode(decoded['result'] as String));
  }

  Future<void> initializeSubscriber({required String deviceUUID}) async {
    final db = await _db;
    final sqlCommands = await _getSqlCommands(deviceUUID);
    for (final entry in sqlCommands.entries) {
      await db.execute(entry.value);
      debugPrint('Executed successfully : ${entry.key}');
    }

    final tableNames = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ?',
      whereArgs: ['table'],
      orderBy: 'name',
    );
    debugPrint(
        'Tables: ${tableNames.map((e) => e['name']).where((element) =>
        element != null).join(
            '\n'
        )}'
    );
    debugPrint('Successfully initialized subscriber');
  }
}
