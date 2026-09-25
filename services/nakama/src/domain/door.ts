// The doors (D-066, D-081). Everything a server-to-server call needs that is not specific
// to one door: who may call, and the rules the door log imposes.
//
// There are two doors and only two: `publish` (releases) and `control` (apply_control,
// D-081, not built yet). Both are logged in directory.door_log, applied or not.

/** gRPC status codes, the few this module returns. */
const CODE_INVALID_ARGUMENT = 3;
const CODE_PERMISSION_DENIED = 7;
const CODE_INTERNAL = 13;

function doorError(code: number, message: string): any {
  return { message: message, code: code };
}

/**
 * A door is server to server. It is never reachable from a phone (D-066).
 *
 * The check is that the call carries no user: Nakama gives an RPC called over HTTP with the
 * runtime HTTP key an empty `ctx.userId`, and a call on a player's session always has one.
 * The HTTP key itself is checked by Nakama before this function runs — a wrong key never
 * reaches the module. So this is the second half of the control, not the whole of it: it
 * stops a signed-in client from reaching a door that Nakama would otherwise let it call.
 */
function requireServerCall(ctx: nkruntime.Context, door: string): void {
  if (ctx.userId) {
    throw doorError(
      CODE_PERMISSION_DENIED,
      door + " is a server-to-server door and is never called on a player's session",
    );
  }
}

/** Reads back a call already logged under this idempotency key, or null if there is none. */
function previousCall(
  nk: nkruntime.Nakama,
  idempotencyKey: string,
): { outcome: string; request_sha256: string; detail: string | null } | null {
  const rows = nk.sqlQuery(
    "SELECT outcome, request_sha256, detail FROM directory.door_log WHERE idempotency_key = $1",
    [idempotencyKey],
  );
  if (rows.length === 0) {
    return null;
  }
  return {
    outcome: rows[0].outcome,
    request_sha256: rows[0].request_sha256,
    detail: rows[0].detail,
  };
}

/** Logs a call that was refused before anything was written. */
function logRejected(
  nk: nkruntime.Nakama,
  door: string,
  caller: string,
  idempotencyKey: string,
  requestSha256: string,
  detail: string,
): void {
  nk.sqlExec(
    "INSERT INTO directory.door_log (door, caller, idempotency_key, request_sha256, outcome, detail)" +
      " VALUES ($1, $2, $3, $4, 'rejected', $5)",
    [door, caller, idempotencyKey, requestSha256, detail],
  );
}

/**
 * The caller recorded in the door log: a key id, never the key and never a person (D-066,
 * R-SEC-06). Nakama does not tell the module which key was used, so until there is more
 * than one publisher this is a constant naming the door's only caller.
 */
const PUBLISH_CALLER = "publish-door";
