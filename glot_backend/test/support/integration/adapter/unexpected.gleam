import glot_backend/system/effect/error/db_error

pub fn query(port: String) -> Result(a, db_error.DbQueryError) {
  Error(db_error.DbQueryError("unexpected test port call: " <> port))
}

pub fn command(port: String) -> Result(a, db_error.DbCommandError) {
  Error(db_error.DbCommandError("unexpected test port call: " <> port))
}
