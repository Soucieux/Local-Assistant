#include "SQLiteVecBridge.h"
#include "sqlite-vec.h"
#include <stddef.h>

/** Registers statically linked sqlite-vec without enabling extension loading. */
int local_assistant_register_sqlite_vec(sqlite3 *database) {
    char *error_message = NULL;
    int result = sqlite3_vec_init(database, &error_message, NULL);
    if (error_message != NULL) {
        sqlite3_free(error_message);
    }
    return result;
}
