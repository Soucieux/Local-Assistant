#ifndef SQLiteVecBridge_h
#define SQLiteVecBridge_h

#include <sqlite3.h>

/** Registers sqlite-vec functions on an open SQLite connection. */
int local_assistant_register_sqlite_vec(sqlite3 *database);

#endif
