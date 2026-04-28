import gleam/dynamic/decode
import gleam/list
import gleam/result
import parrot/dev
import pog

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
  db: pog.Connection,
  query: ExecuteParams,
  to_error: fn(pog.QueryError) -> e,
) -> Result(pog.Returned(Nil), e) {
  let #(sql, params) = query
  let pog_params = list.map(params, parrot_to_pog)

  pog.query(sql)
  |> add_params(pog_params)
  |> pog.execute(db)
  |> result.map_error(to_error)
}

pub type QueryParams(a) =
  #(String, List(dev.Param), decode.Decoder(a))

pub fn query(
  db: pog.Connection,
  query: QueryParams(a),
  to_error: fn(pog.QueryError) -> e,
) -> Result(pog.Returned(a), e) {
  let #(sql, params, decoder) = query
  let pog_params = list.map(params, parrot_to_pog)

  pog.query(sql)
  |> add_params(pog_params)
  |> pog.returning(decoder)
  |> pog.execute(db)
  |> result.map_error(to_error)
}

fn add_params(q: pog.Query(Nil), params: List(pog.Value)) -> pog.Query(Nil) {
  list.fold(params, q, fn(acc, param) { pog.parameter(acc, param) })
}
