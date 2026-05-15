import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import parrot/dev
import pog

pub const default_statement_timeout_ms = 10_000

const timeout_grace_ms = 1_000

pub opaque type Db {
  Db(connection: pog.Connection, timeout_ms: Int)
}

pub fn new(connection: pog.Connection) -> Db {
  Db(connection:, timeout_ms: default_query_timeout_ms())
}

pub fn override_timeout(db: Db, timeout_ms: option.Option(Int)) -> Db {
  case timeout_ms {
    option.Some(timeout_ms) ->
      Db(..db, timeout_ms: query_timeout_ms(timeout_ms))
    option.None -> db
  }
}

pub fn timeout_ms(db: Db) -> Int {
  db.timeout_ms
}

pub fn connection(db: Db) -> pog.Connection {
  db.connection
}

pub fn query_timeout_ms(statement_timeout_ms: Int) -> Int {
  statement_timeout_ms + timeout_grace_ms
}

pub fn default_query_timeout_ms() -> Int {
  query_timeout_ms(default_statement_timeout_ms)
}

pub fn statement_timeout_parameter() -> String {
  int.to_string(default_statement_timeout_ms) <> "ms"
}

pub fn parrot_to_pog(param: dev.Param) -> pog.Value {
  case param {
    dev.ParamDynamic(_) ->
      panic as "Got a dynamic parrot value, this should not happen"
    dev.ParamBool(x) -> pog.bool(x)
    dev.ParamFloat(x) -> pog.float(x)
    dev.ParamInt(x) -> pog.int(x)
    dev.ParamString(x) -> pog.text(x)
    dev.ParamBitArray(x) -> pog.bytea(x)
    dev.ParamList(x) -> pog.array(parrot_to_pog, x)
    dev.ParamNullable(x) -> pog.nullable(fn(a) { parrot_to_pog(a) }, x)
    dev.ParamDate(x) -> pog.calendar_date(x)
    dev.ParamTimestamp(x) -> pog.timestamp(x)
  }
}

pub type ExecuteParams =
  #(String, List(dev.Param))

pub fn execute(
  db: Db,
  query: ExecuteParams,
  to_error: fn(pog.QueryError) -> e,
) -> Result(pog.Returned(Nil), e) {
  let #(sql, params) = query
  let pog_params = list.map(params, parrot_to_pog)

  pog.query(sql)
  |> apply_timeout(db)
  |> add_params(pog_params)
  |> pog.execute(db.connection)
  |> result.map_error(to_error)
}

pub type QueryParams(a) =
  #(String, List(dev.Param), decode.Decoder(a))

pub fn query(
  db: Db,
  query: QueryParams(a),
  to_error: fn(pog.QueryError) -> e,
) -> Result(pog.Returned(a), e) {
  let #(sql, params, decoder) = query
  let pog_params = list.map(params, parrot_to_pog)

  pog.query(sql)
  |> apply_timeout(db)
  |> add_params(pog_params)
  |> pog.returning(decoder)
  |> pog.execute(db.connection)
  |> result.map_error(to_error)
}

fn apply_timeout(query: pog.Query(a), db: Db) -> pog.Query(a) {
  pog.timeout(query, db.timeout_ms)
}

fn add_params(q: pog.Query(Nil), params: List(pog.Value)) -> pog.Query(Nil) {
  list.fold(params, q, fn(acc, param) { pog.parameter(acc, param) })
}
