import gleam/list
import gleam/option
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/pagination_model
import glot_core/snippet/snippet_model

type PageDirection {
  InitialPage
  AfterPage
  BeforePage
}

pub fn validate_page_request(
  pagination: pagination_model.CursorPagination,
) -> program_types.Program(Nil) {
  let pagination_model.CursorPagination(after:, before:, limit:) = pagination
  use _ <- program.and_then(require(
    limit > 0,
    "limit must be greater than 0",
  ))
  use _ <- program.and_then(require(
    limit <= 100,
    "limit must be less than or equal to 100",
  ))
  use _ <- program.and_then(require(
    has_at_most_one_cursor(after, before),
    "after and before cannot both be set",
  ))

  program.succeed(Nil)
}

pub fn paginate_snippets(
  snippets: List(snippet_model.HydratedSnippet),
  pagination: pagination_model.CursorPagination,
) -> #(
  List(snippet_model.HydratedSnippet),
  option.Option(String),
  option.Option(String),
) {
  let pagination_model.CursorPagination(after:, before:, limit:) = pagination
  let direction = page_direction(after, before)
  let #(page, has_more) = take_page(snippets, limit)

  case direction {
    InitialPage ->
      #(page, option.None, maybe_last_slug(page, has_more))
    AfterPage ->
      #(page, maybe_first_slug(page), maybe_last_slug(page, has_more))
    BeforePage ->
      #(
        page,
        maybe_first_slug_when(page, has_more),
        maybe_last_slug(page, True),
      )
  }
}

fn require(condition: Bool, message: String) -> program_types.Program(Nil) {
  case condition {
    True -> program.succeed(Nil)
    False -> program.fail(error.ValidationError(message))
  }
}

fn has_at_most_one_cursor(
  after: option.Option(String),
  before: option.Option(String),
) -> Bool {
  case after, before {
    option.Some(_), option.Some(_) -> False
    _, _ -> True
  }
}

fn take_page(
  snippets: List(snippet_model.HydratedSnippet),
  limit: Int,
) -> #(List(snippet_model.HydratedSnippet), Bool) {
  take_page_loop(snippets, limit, [])
}

fn take_page_loop(
  snippets: List(snippet_model.HydratedSnippet),
  remaining: Int,
  acc: List(snippet_model.HydratedSnippet),
) -> #(List(snippet_model.HydratedSnippet), Bool) {
  case snippets {
    [] -> #(list.reverse(acc), False)
    [snippet, ..rest] ->
      case remaining > 0 {
        True ->
          take_page_loop(
            rest,
            remaining - 1,
            [snippet, ..acc],
          )
        False -> #(list.reverse(acc), True)
      }
  }
}

fn page_direction(
  after: option.Option(String),
  before: option.Option(String),
) -> PageDirection {
  case after, before {
    _, option.Some(_) -> BeforePage
    option.Some(_), option.None -> AfterPage
    option.None, option.None -> InitialPage
  }
}

fn maybe_first_slug(
  snippets: List(snippet_model.HydratedSnippet),
) -> option.Option(String) {
  maybe_first_slug_when(snippets, True)
}

fn maybe_first_slug_when(
  snippets: List(snippet_model.HydratedSnippet),
  when: Bool,
) -> option.Option(String) {
  case when, snippets {
    True, [snippet, ..] -> option.Some(snippet.identity.slug)
    _, _ -> option.None
  }
}

fn maybe_last_slug(
  snippets: List(snippet_model.HydratedSnippet),
  when: Bool,
) -> option.Option(String) {
  case when, list.reverse(snippets) {
    True, [snippet, ..] -> option.Some(snippet.identity.slug)
    _, _ -> option.None
  }
}
