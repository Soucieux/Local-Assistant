#!/bin/zsh
# Checks the index-activity SQL contract the app relies on: an interrupted run's items fall
# back to waiting states, revoking a root cascades to its items and monitoring state while
# activity history stays, retention deletes only old runs and events, and clearing runs
# removes their items. It then compiles and runs IndexingDecisionChecks.swift against the app's
# own indexing decision policy.
#
# Input:  none; requires sqlite3 and the Xcode toolchain
# Reads:  LocalAssistant/Constants/FileConstants.swift, Indexing/IndexingDecisionPolicy.swift,
#         Persistence/AssistantDatabase+Activity.swift and Scripts/IndexingDecisionChecks.swift
# Writes: a temporary directory, removed on exit
# Run by: hand, as the documented index-activity check
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
TEST_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/local-assistant-activity.XXXXXX")"
DATABASE_PATH="${TEST_DIRECTORY}/activity.sqlite3"

cleanup() {
  rm -rf -- "${TEST_DIRECTORY}"
}

fail() {
  print -u2 -- "Index activity check failed: $1"
  exit 1
}

assert_query() {
  local expected="$1"
  local query="$2"
  local actual
  actual="$(/usr/bin/sqlite3 "${DATABASE_PATH}" "${query}")"
  [[ "${actual}" == "${expected}" ]] || fail "expected '${expected}', received '${actual}'"
}

trap cleanup EXIT

/usr/bin/sqlite3 "${DATABASE_PATH}" <<'SQL'
PRAGMA foreign_keys = ON;

CREATE TABLE authorized_roots (
  id TEXT PRIMARY KEY NOT NULL
);
CREATE TABLE indexed_items (
  id TEXT PRIMARY KEY NOT NULL,
  root_id TEXT NOT NULL REFERENCES authorized_roots(id) ON DELETE CASCADE
);
CREATE TABLE folder_monitoring_states (
  root_id TEXT PRIMARY KEY NOT NULL REFERENCES authorized_roots(id) ON DELETE CASCADE,
  is_enabled INTEGER NOT NULL,
  updated_at REAL NOT NULL
);
CREATE TABLE indexing_runs (
  id TEXT PRIMARY KEY NOT NULL,
  root_id TEXT NOT NULL,
  folder_name TEXT NOT NULL,
  folder_path TEXT NOT NULL,
  trigger TEXT NOT NULL,
  state TEXT NOT NULL,
  started_at REAL NOT NULL,
  finished_at REAL,
  total_items INTEGER NOT NULL,
  new_items INTEGER NOT NULL,
  updated_items INTEGER NOT NULL,
  unchanged_items INTEGER NOT NULL,
  removed_items INTEGER NOT NULL,
  skipped_items INTEGER NOT NULL
);
CREATE TABLE indexing_run_items (
  id TEXT PRIMARY KEY NOT NULL,
  run_id TEXT NOT NULL REFERENCES indexing_runs(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  relative_path TEXT NOT NULL,
  state TEXT NOT NULL,
  detail TEXT,
  updated_at REAL NOT NULL,
  UNIQUE(run_id, relative_path)
);
CREATE TABLE index_activity_events (
  id TEXT PRIMARY KEY NOT NULL,
  root_id TEXT NOT NULL,
  folder_name TEXT NOT NULL,
  kind TEXT NOT NULL,
  occurred_at REAL NOT NULL
);

INSERT INTO authorized_roots VALUES ('root-live');
INSERT INTO indexed_items VALUES ('indexed-live', 'root-live');
INSERT INTO folder_monitoring_states VALUES ('root-live', 1, 100);
INSERT INTO indexing_runs VALUES (
  'run-interrupted', 'root-live', 'Folder', '/Folder', 'automatic', 'running',
  100, NULL, 2, 0, 0, 0, 0, 0
);
INSERT INTO indexing_run_items VALUES (
  'item-new', 'run-interrupted', 'new.txt', 'new.txt', 'newIndexing', NULL, 100
);
INSERT INTO indexing_run_items VALUES (
  'item-modified', 'run-interrupted', 'changed.txt', 'changed.txt',
  'modifiedUpdating', NULL, 100
);
INSERT INTO index_activity_events VALUES (
  'event-live', 'root-live', 'Folder', 'changesDetected', 100
);

UPDATE indexing_run_items
SET state = CASE state
    WHEN 'newIndexing' THEN 'newWaiting'
    WHEN 'modifiedUpdating' THEN 'modifiedWaiting'
    ELSE state
  END,
  updated_at = 200
WHERE run_id IN (SELECT id FROM indexing_runs WHERE state = 'running')
  AND state IN ('newIndexing', 'modifiedUpdating');
UPDATE indexing_runs SET state = 'stopped', finished_at = 200 WHERE state = 'running';
SQL

assert_query "modifiedWaiting|newWaiting" \
  "SELECT group_concat(state, '|') FROM (SELECT state FROM indexing_run_items ORDER BY id);"
assert_query "stopped|200.0" \
  "SELECT state || '|' || finished_at FROM indexing_runs WHERE id = 'run-interrupted';"

/usr/bin/sqlite3 "${DATABASE_PATH}" "PRAGMA foreign_keys = ON; DELETE FROM authorized_roots WHERE id = 'root-live';"

assert_query "0|0|1|2|1" \
  "SELECT (SELECT count(*) FROM authorized_roots) || '|' || (SELECT count(*) FROM indexed_items) || '|' || (SELECT count(*) FROM indexing_runs) || '|' || (SELECT count(*) FROM indexing_run_items) || '|' || (SELECT count(*) FROM index_activity_events);"

/usr/bin/sqlite3 "${DATABASE_PATH}" <<'SQL'
PRAGMA foreign_keys = ON;
INSERT INTO authorized_roots VALUES ('root-current');
INSERT INTO indexed_items VALUES ('indexed-current', 'root-current');
INSERT INTO indexing_runs VALUES (
  'run-old', 'revoked-root', 'Old', '/Old', 'manual', 'completed',
  500, 510, 1, 1, 0, 0, 0, 0
);
INSERT INTO indexing_run_items VALUES (
  'item-old', 'run-old', 'old.txt', 'old.txt', 'newIndexed', NULL, 510
);
INSERT INTO indexing_runs VALUES (
  'run-current', 'revoked-root', 'Current', '/Current', 'manual', 'completed',
  1500, 1510, 1, 1, 0, 0, 0, 0
);
INSERT INTO indexing_run_items VALUES (
  'item-current', 'run-current', 'current.txt', 'current.txt', 'newIndexed', NULL, 1510
);
INSERT INTO index_activity_events VALUES (
  'event-old', 'revoked-root', 'Old', 'monitoringPaused', 500
);
INSERT INTO index_activity_events VALUES (
  'event-current', 'revoked-root', 'Current', 'monitoringPaused', 1500
);
DELETE FROM indexing_runs WHERE started_at < 1000;
DELETE FROM index_activity_events WHERE occurred_at < 1000;
SQL

assert_query "run-current|item-current|event-current" \
  "SELECT (SELECT id FROM indexing_runs) || '|' || (SELECT id FROM indexing_run_items) || '|' || (SELECT id FROM index_activity_events);"

/usr/bin/sqlite3 "${DATABASE_PATH}" <<'SQL'
PRAGMA foreign_keys = ON;
DELETE FROM indexing_runs;
DELETE FROM index_activity_events;
SQL

assert_query "0|0|0|1|1" \
  "SELECT (SELECT count(*) FROM indexing_runs) || '|' || (SELECT count(*) FROM indexing_run_items) || '|' || (SELECT count(*) FROM index_activity_events) || '|' || (SELECT count(*) FROM authorized_roots) || '|' || (SELECT count(*) FROM indexed_items);"

[[ -f "${SCRIPT_DIR}/../LocalAssistant/Persistence/AssistantDatabase+Activity.swift" ]] \
  || fail "activity persistence source is missing"

/usr/bin/xcrun swiftc \
  -parse-as-library \
  "${SCRIPT_DIR}/../LocalAssistant/Constants/FileConstants.swift" \
  "${SCRIPT_DIR}/../LocalAssistant/Indexing/IndexingDecisionPolicy.swift" \
  "${SCRIPT_DIR}/IndexingDecisionChecks.swift" \
  -o "${TEST_DIRECTORY}/indexing-decision-checks"
"${TEST_DIRECTORY}/indexing-decision-checks"

print "Index activity checks passed."
