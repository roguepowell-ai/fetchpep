// Ambient declarations for the part of the Nakama JavaScript runtime this module uses.
//
// Heroic Labs ships `nakama-runtime` from the nakama-common repository rather than the npm
// registry, so taking it would mean a dependency on a git URL. This file is the subset we
// actually call, written out. It is smaller than the real thing and deliberately so: if
// something here is wrong, the server refuses to start and the local run in the pull
// request catches it, which is a better signal than a type that merely looks right.
//
// Checked against Nakama 3.40.0 (ops/VERSIONS.ops.md).

declare namespace nkruntime {
  /** gRPC status codes. Nakama turns a thrown `{ message, code }` into this status. */
  type Code = number;

  interface Context {
    /** Empty for a call made with the runtime HTTP key; set for a call on a session. */
    readonly userId: string;
    readonly username: string;
    readonly clientIp: string;
    readonly clientPort: string;
  }

  interface Logger {
    debug(format: string, ...args: any[]): void;
    info(format: string, ...args: any[]): void;
    warn(format: string, ...args: any[]): void;
    error(format: string, ...args: any[]): void;
  }

  interface SqlExecResult {
    rowsAffected: number;
  }

  /** One object per row, keyed by column name. */
  type SqlQueryResult = { [column: string]: any }[];

  interface Nakama {
    sqlExec(query: string, parameters?: any[]): SqlExecResult;
    sqlQuery(query: string, parameters?: any[]): SqlQueryResult;
    sha256Hash(input: string): string;
  }

  type RpcFunction = (
    ctx: Context,
    logger: Logger,
    nk: Nakama,
    payload: string,
  ) => string | void;

  interface Initializer {
    registerRpc(id: string, func: RpcFunction): void;
  }
}
