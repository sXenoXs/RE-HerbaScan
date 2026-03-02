// Desktop (Windows/Linux/macOS): set global databaseFactory so sqflite uses FFI.
// Mobile and web never call this; mobile keeps using platform sqflite.

import 'package:sqflite_common/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;

void initDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
