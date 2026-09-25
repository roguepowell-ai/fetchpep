// The game logic (D-062): TypeScript modules inside open-source Nakama, compiled to one
// JavaScript file that Nakama loads at start.
//
// Nakama refuses to start if this function is missing or throws, so a mistake here is a
// server that does not come up rather than one that comes up wrong.

function InitModule(
  ctx: nkruntime.Context,
  logger: nkruntime.Logger,
  nk: nkruntime.Nakama,
  initializer: nkruntime.Initializer,
): void {
  // RPC ids are snake_case verbs (spec/DATA-MODEL.spec.md, *Files and names*).
  initializer.registerRpc("publish_release", publishRelease);
  initializer.registerRpc("read_catalogue", readCatalogue);

  // D-079 says all game data lives in our own tables, written by this runtime. That the
  // runtime can reach them at all is the thing pass 1 has to prove, so it is checked here,
  // at start, rather than discovered on the first call: if `directory` is not there or is
  // not readable, the server does not start.
  const rows = nk.sqlQuery(
    "SELECT count(*)::int AS applied FROM directory.schema_migration",
    [],
  );
  // Nakama's logger formats with Go verbs, and a count comes back from SQL as an int64,
  // so %d rather than %s — %s prints it as `%!s(int64=2)`.
  logger.info(
    "fetchpep: module loaded, %d migration(s) applied, 2 rpc(s) registered",
    rows[0].applied,
  );
}
