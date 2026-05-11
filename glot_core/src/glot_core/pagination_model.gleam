import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option

pub type Cursor {
  Cursor(String)
}

pub type CursorPagination {
  InitialPage(limit: Int)
  AfterPage(cursor: Cursor, limit: Int)
  BeforePage(cursor: Cursor, limit: Int)
}

pub type CursorPage(a) {
  InitialCursorPage(items: List(a), next_cursor: option.Option(Cursor))
  AfterCursorPage(
    items: List(a),
    previous_cursor: Cursor,
    next_cursor: option.Option(Cursor),
  )
  BeforeCursorPage(
    items: List(a),
    previous_cursor: option.Option(Cursor),
    next_cursor: Cursor,
  )
}

type PageSlice(a) {
  PageSlice(items: List(a), has_more: Bool)
}

pub fn from_string(value: String) -> Cursor {
  Cursor(value)
}

pub fn to_string(cursor: Cursor) -> String {
  let Cursor(value) = cursor
  value
}

pub fn request_decoder() -> decode.Decoder(CursorPagination) {
  decode.field("pageKind", decode.string, fn(page_kind) {
    case page_kind {
      "initial" ->
        decode.field("limit", decode.int, fn(limit) {
          decode.success(InitialPage(limit: limit))
        })
      "after" ->
        decode.field("cursor", decode.string, fn(cursor) {
          decode.field("limit", decode.int, fn(limit) {
            decode.success(AfterPage(cursor: Cursor(cursor), limit: limit))
          })
        })
      "before" ->
        decode.field("cursor", decode.string, fn(cursor) {
          decode.field("limit", decode.int, fn(limit) {
            decode.success(BeforePage(cursor: Cursor(cursor), limit: limit))
          })
        })
      _ -> decode.failure(InitialPage(limit: 1), "CursorPagination")
    }
  })
}

pub fn encode_request_fields(
  pagination: CursorPagination,
) -> List(#(String, json.Json)) {
  case pagination {
    InitialPage(limit) -> [
      #("pageKind", json.string("initial")),
      #("limit", json.int(limit)),
    ]
    AfterPage(cursor, limit) -> [
      #("pageKind", json.string("after")),
      #("cursor", json.string(to_string(cursor))),
      #("limit", json.int(limit)),
    ]
    BeforePage(cursor, limit) -> [
      #("pageKind", json.string("before")),
      #("cursor", json.string(to_string(cursor))),
      #("limit", json.int(limit)),
    ]
  }
}

pub fn page_decoder(
  item_field: String,
  item_decoder: decode.Decoder(a),
) -> decode.Decoder(CursorPage(a)) {
  decode.field("pageKind", decode.string, fn(page_kind) {
    case page_kind {
      "initial" ->
        decode.field(item_field, decode.list(item_decoder), fn(items) {
          decode.field(
            "nextCursor",
            decode.optional(decode.map(decode.string, Cursor)),
            fn(next_cursor) {
              decode.success(InitialCursorPage(
                items: items,
                next_cursor: next_cursor,
              ))
            },
          )
        })
      "after" ->
        decode.field(item_field, decode.list(item_decoder), fn(items) {
          decode.field(
            "previousCursor",
            decode.map(decode.string, Cursor),
            fn(previous_cursor) {
              decode.field(
                "nextCursor",
                decode.optional(decode.map(decode.string, Cursor)),
                fn(next_cursor) {
                  decode.success(AfterCursorPage(
                    items: items,
                    previous_cursor: previous_cursor,
                    next_cursor: next_cursor,
                  ))
                },
              )
            },
          )
        })
      "before" ->
        decode.field(item_field, decode.list(item_decoder), fn(items) {
          decode.field(
            "previousCursor",
            decode.optional(decode.map(decode.string, Cursor)),
            fn(previous_cursor) {
              decode.field(
                "nextCursor",
                decode.map(decode.string, Cursor),
                fn(next_cursor) {
                  decode.success(BeforeCursorPage(
                    items: items,
                    previous_cursor: previous_cursor,
                    next_cursor: next_cursor,
                  ))
                },
              )
            },
          )
        })
      _ ->
        decode.failure(
          InitialCursorPage(items: [], next_cursor: option.None),
          "CursorPage",
        )
    }
  })
}

pub fn encode_page(
  page: CursorPage(a),
  item_field: String,
  item_encoder: fn(a) -> json.Json,
) -> json.Json {
  case page {
    InitialCursorPage(items, next_cursor) ->
      json.object([
        #("pageKind", json.string("initial")),
        #(item_field, json.array(items, item_encoder)),
        #("nextCursor", json.nullable(next_cursor, encode_cursor_json)),
      ])
    AfterCursorPage(items, previous_cursor, next_cursor) ->
      json.object([
        #("pageKind", json.string("after")),
        #(item_field, json.array(items, item_encoder)),
        #("previousCursor", encode_cursor_json(previous_cursor)),
        #("nextCursor", json.nullable(next_cursor, encode_cursor_json)),
      ])
    BeforeCursorPage(items, previous_cursor, next_cursor) ->
      json.object([
        #("pageKind", json.string("before")),
        #(item_field, json.array(items, item_encoder)),
        #("previousCursor", json.nullable(previous_cursor, encode_cursor_json)),
        #("nextCursor", encode_cursor_json(next_cursor)),
      ])
  }
}

pub fn validate(
  pagination: CursorPagination,
  max_limit: Int,
) -> Result(Nil, String) {
  let page_limit = limit(pagination)
  case page_limit <= 0 {
    True -> Error("limit must be greater than 0")
    False ->
      case page_limit <= max_limit {
        True -> Ok(Nil)
        False ->
          Error(
            "limit must be less than or equal to " <> int.to_string(max_limit),
          )
      }
  }
}

pub fn increment_limit(pagination: CursorPagination) -> CursorPagination {
  case pagination {
    InitialPage(limit) -> InitialPage(limit: limit + 1)
    AfterPage(cursor, limit) -> AfterPage(cursor: cursor, limit: limit + 1)
    BeforePage(cursor, limit) -> BeforePage(cursor: cursor, limit: limit + 1)
  }
}

pub fn limit(pagination: CursorPagination) -> Int {
  case pagination {
    InitialPage(limit) -> limit
    AfterPage(_, limit) -> limit
    BeforePage(_, limit) -> limit
  }
}

pub fn paginate(
  items: List(a),
  pagination: CursorPagination,
  get_cursor: fn(a) -> Cursor,
) -> CursorPage(a) {
  case pagination {
    InitialPage(limit: _) -> {
      let PageSlice(items: page_items, has_more: has_more) =
        take_page(items, limit(pagination))

      InitialCursorPage(
        items: page_items,
        next_cursor: maybe_last_cursor(page_items, has_more, get_cursor),
      )
    }

    AfterPage(cursor: request_cursor, limit: _) -> {
      let PageSlice(items: page_items, has_more: has_more) =
        take_page(items, limit(pagination))

      AfterCursorPage(
        items: page_items,
        previous_cursor: after_previous_cursor(
          page_items,
          request_cursor,
          get_cursor,
        ),
        next_cursor: maybe_last_cursor(page_items, has_more, get_cursor),
      )
    }

    BeforePage(cursor: request_cursor, limit: _) -> {
      let PageSlice(items: page_items, has_more: has_more) =
        take_page_from_end(items, limit(pagination))

      BeforeCursorPage(
        items: page_items,
        previous_cursor: maybe_first_cursor_when(
          page_items,
          has_more,
          get_cursor,
        ),
        next_cursor: before_next_cursor(page_items, request_cursor, get_cursor),
      )
    }
  }
}

pub fn items(page: CursorPage(a)) -> List(a) {
  case page {
    InitialCursorPage(items:, next_cursor: _) -> items
    AfterCursorPage(items:, previous_cursor: _, next_cursor: _) -> items
    BeforeCursorPage(items:, previous_cursor: _, next_cursor: _) -> items
  }
}

pub fn previous_cursor(page: CursorPage(a)) -> option.Option(Cursor) {
  case page {
    InitialCursorPage(items: _, next_cursor: _) -> option.None
    AfterCursorPage(items: _, previous_cursor: previous_cursor, next_cursor: _) ->
      option.Some(previous_cursor)
    BeforeCursorPage(items: _, previous_cursor: previous_cursor, next_cursor: _) ->
      previous_cursor
  }
}

pub fn next_cursor(page: CursorPage(a)) -> option.Option(Cursor) {
  case page {
    InitialCursorPage(items: _, next_cursor: next_cursor) -> next_cursor
    AfterCursorPage(items: _, previous_cursor: _, next_cursor: next_cursor) ->
      next_cursor
    BeforeCursorPage(items: _, previous_cursor: _, next_cursor: next_cursor) ->
      option.Some(next_cursor)
  }
}

pub fn map_page(page: CursorPage(a), f: fn(a) -> b) -> CursorPage(b) {
  case page {
    InitialCursorPage(items:, next_cursor:) ->
      InitialCursorPage(items: list.map(items, f), next_cursor: next_cursor)
    AfterCursorPage(items:, previous_cursor:, next_cursor:) ->
      AfterCursorPage(
        items: list.map(items, f),
        previous_cursor: previous_cursor,
        next_cursor: next_cursor,
      )
    BeforeCursorPage(items:, previous_cursor:, next_cursor:) ->
      BeforeCursorPage(
        items: list.map(items, f),
        previous_cursor: previous_cursor,
        next_cursor: next_cursor,
      )
  }
}

fn encode_cursor_json(cursor: Cursor) -> json.Json {
  json.string(to_string(cursor))
}

fn take_page(items: List(a), page_limit: Int) -> PageSlice(a) {
  take_page_loop(items, page_limit, [])
}

fn take_page_from_end(items: List(a), page_limit: Int) -> PageSlice(a) {
  items
  |> list.reverse
  |> take_page(page_limit)
  |> reverse_page_slice
}

fn take_page_loop(
  items: List(a),
  remaining: Int,
  acc: List(a),
) -> PageSlice(a) {
  case items {
    [] -> PageSlice(items: list.reverse(acc), has_more: False)
    [item, ..rest] ->
      case remaining > 0 {
        True -> take_page_loop(rest, remaining - 1, [item, ..acc])
        False -> PageSlice(items: list.reverse(acc), has_more: True)
      }
  }
}

fn maybe_first_cursor(
  items: List(a),
  get_cursor: fn(a) -> Cursor,
) -> option.Option(Cursor) {
  maybe_first_cursor_when(items, True, get_cursor)
}

fn maybe_first_cursor_when(
  items: List(a),
  when: Bool,
  get_cursor: fn(a) -> Cursor,
) -> option.Option(Cursor) {
  case when, items {
    True, [item, ..] -> option.Some(get_cursor(item))
    _, _ -> option.None
  }
}

fn maybe_last_cursor(
  items: List(a),
  when: Bool,
  get_cursor: fn(a) -> Cursor,
) -> option.Option(Cursor) {
  case when, list.reverse(items) {
    True, [item, ..] -> option.Some(get_cursor(item))
    _, _ -> option.None
  }
}

fn after_previous_cursor(
  items: List(a),
  request_cursor: Cursor,
  get_cursor: fn(a) -> Cursor,
) -> Cursor {
  case maybe_first_cursor(items, get_cursor) {
    option.Some(cursor) -> cursor
    option.None -> request_cursor
  }
}

fn before_next_cursor(
  items: List(a),
  request_cursor: Cursor,
  get_cursor: fn(a) -> Cursor,
) -> Cursor {
  case maybe_last_cursor(items, True, get_cursor) {
    option.Some(cursor) -> cursor
    option.None -> request_cursor
  }
}

fn reverse_page_slice(slice: PageSlice(a)) -> PageSlice(a) {
  let PageSlice(items: items, has_more: has_more) = slice
  PageSlice(items: list.reverse(items), has_more: has_more)
}
