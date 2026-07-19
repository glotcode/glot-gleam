import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/loadable
import glot_core/pagination_model
import glot_core/route
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/delayed_loading
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

const page_limit = 10

const delete_dialog_id = "manage-snippets-page-delete-dialog"

pub type Model {
  Model(
    page: loadable.Loadable(
      pagination_model.CursorPage(snippet_dto.SnippetResponse),
    ),
    after: option.Option(String),
    before: option.Option(String),
    pending_delete: option.Option(snippet_dto.SnippetResponse),
    deleting_slug: option.Option(String),
    mutation_error: option.Option(String),
    request: Request,
    loading_indicator: delayed_loading.State,
  )
}

pub opaque type Request {
  Request(after: option.Option(String), before: option.Option(String))
}

pub fn init(
  after after: option.Option(String),
  before before: option.Option(String),
) -> #(Model, Effect(Msg)) {
  let request = Request(after:, before:)
  let #(loading_indicator, delay_effect) =
    delayed_loading.start(delayed_loading.idle(), fn(generation) {
      LoadingDelayElapsed(request, generation)
    })
  let model =
    Model(
      page: loadable.Loading,
      after: after,
      before: before,
      pending_delete: option.None,
      deleting_slug: option.None,
      mutation_error: option.None,
      request:,
      loading_indicator:,
    )

  #(model, effect.batch([load_page(request), delay_effect]))
}

pub type Msg {
  SnippetsLoaded(Request, api.ApiResponse(snippet_dto.ListSnippetsResponse))
  LoadingDelayElapsed(Request, Int)
  NextPageClicked
  PreviousPageClicked
  DeleteClicked(String)
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed(String)
  DeleteFinished(String, api.ApiResponse(Nil))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(request, result) ->
      case request == model.request, result {
        False, _ -> #(model, effect.none())
        True, api.ApiSuccess(response) -> #(
          Model(
            ..model,
            page: loadable.Loaded(response.page),
            pending_delete: option.None,
            mutation_error: option.None,
            loading_indicator: delayed_loading.finish(model.loading_indicator),
          ),
          effect.none(),
        )
        True, api.ApiFailure(error) -> #(
          Model(
            ..model,
            page: loadable.LoadError(api.error_message(error)),
            pending_delete: option.None,
            loading_indicator: delayed_loading.finish(model.loading_indicator),
          ),
          effect.none(),
        )
        True, api.HttpFailure(_) -> #(
          Model(
            ..model,
            page: loadable.LoadError("Could not load your snippets."),
            pending_delete: option.None,
            loading_indicator: delayed_loading.finish(model.loading_indicator),
          ),
          effect.none(),
        )
      }

    LoadingDelayElapsed(request, generation) ->
      case request == model.request {
        True -> #(
          Model(
            ..model,
            loading_indicator: delayed_loading.reveal(
              model.loading_indicator,
              generation,
            ),
          ),
          effect.none(),
        )
        False -> #(model, effect.none())
      }

    NextPageClicked ->
      case next_cursor(model) {
        option.Some(next_cursor) -> #(
          model,
          navigate_to(
            option.Some(pagination_model.to_string(next_cursor)),
            option.None,
          ),
        )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case previous_cursor(model) {
        option.Some(previous_cursor) -> #(
          model,
          navigate_to(
            option.None,
            option.Some(pagination_model.to_string(previous_cursor)),
          ),
        )
        option.None -> #(model, effect.none())
      }

    DeleteClicked(slug) ->
      case find_loaded_snippet(model.page, slug) {
        option.Some(snippet) -> #(
          Model(..model, pending_delete: option.Some(snippet)),
          app_dialog.open(delete_dialog_id),
        )
        option.None -> #(model, effect.none())
      }

    DeleteCancelled -> #(model, app_dialog.close(delete_dialog_id))

    DeleteDialogClosed -> #(
      Model(..model, pending_delete: option.None),
      effect.none(),
    )

    DeleteConfirmed(slug) -> #(
      Model(
        ..model,
        deleting_slug: option.Some(slug),
        mutation_error: option.None,
      ),
      effect.batch([
        app_dialog.close(delete_dialog_id),
        api.delete_snippet(
          snippet_dto.DeleteSnippetRequest(slug: slug),
          fn(result) { DeleteFinished(slug, result) },
        ),
      ]),
    )

    DeleteFinished(_, result) ->
      case result {
        api.ApiSuccess(_) -> {
          let #(loading_indicator, delay_effect) =
            delayed_loading.start(model.loading_indicator, fn(generation) {
              LoadingDelayElapsed(model.request, generation)
            })
          #(
            Model(
              ..model,
              page: loadable.Loading,
              pending_delete: option.None,
              deleting_slug: option.None,
              mutation_error: option.None,
              loading_indicator:,
            ),
            effect.batch([load_page(model.request), delay_effect]),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            pending_delete: option.None,
            deleting_slug: option.None,
            mutation_error: option.Some(api.error_message(error)),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            pending_delete: option.None,
            deleting_slug: option.None,
            mutation_error: option.Some("Could not delete snippet."),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main(
      [
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("app-shell"),
      ],
      [
        html.section([attribute.class("app-panel snippets-page")], [
          html.div([attribute.class("snippets-page__header")], [
            html.div([], [
              html.h1([attribute.class("snippets-page__title")], [
                html.text("Your snippets"),
              ]),
              html.p([attribute.class("snippets-page__status")], [
                html.text("Manage snippets created in your account."),
              ]),
            ]),
            html.div([attribute.class("snippets-page__pagination")], [
              pagination_button(
                "Previous",
                PreviousPageClicked,
                can_go_previous(model),
              ),
              pagination_button("Next", NextPageClicked, can_go_next(model)),
            ]),
          ]),
          status_view(model),
          content_view(model, now),
        ]),
      ],
    ),
    delete_confirmation_dialog(model),
  ])
}

fn load_page(request: Request) -> Effect(Msg) {
  api.list_session_snippets(
    snippet_dto.ListSessionSnippetsRequest(pagination: pagination_from_cursors(
      request.after,
      request.before,
    )),
    fn(result) { SnippetsLoaded(request, result) },
  )
}

fn pagination_from_cursors(
  after: option.Option(String),
  before: option.Option(String),
) -> pagination_model.CursorPagination {
  case after, before {
    option.Some(cursor), option.None ->
      pagination_model.AfterPage(
        cursor: pagination_model.from_string(cursor),
        limit: page_limit,
      )
    option.None, option.Some(cursor) ->
      pagination_model.BeforePage(
        cursor: pagination_model.from_string(cursor),
        limit: page_limit,
      )
    option.None, option.None -> pagination_model.InitialPage(limit: page_limit)
    option.Some(_), option.Some(_) ->
      pagination_model.InitialPage(limit: page_limit)
  }
}

fn can_go_previous(model: Model) -> Bool {
  case previous_cursor(model), model.deleting_slug {
    option.Some(_), option.None -> True
    _, _ -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case next_cursor(model), model.deleting_slug {
    option.Some(_), option.None -> True
    _, _ -> False
  }
}

fn previous_cursor(model: Model) -> option.Option(pagination_model.Cursor) {
  case model.page {
    loadable.Loaded(page) -> pagination_model.previous_cursor(page)
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> option.None
  }
}

fn next_cursor(model: Model) -> option.Option(pagination_model.Cursor) {
  case model.page {
    loadable.Loaded(page) -> pagination_model.next_cursor(page)
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> option.None
  }
}

fn status_view(model: Model) -> Element(Msg) {
  case
    model.mutation_error,
    model.deleting_slug,
    model.page,
    delayed_loading.is_visible(model.loading_indicator)
  {
    option.Some(message), _, _, _ -> error_status(message)
    _, option.Some(_), _, _ -> info_status("Deleting snippet...")
    _, _, loadable.LoadError(message), _ -> error_status(message)
    _, _, loadable.Loading, True -> info_status("Loading your snippets...")
    _, _, loadable.NotLoaded, _
    | _, _, loadable.Loading, False
    | _, _, loadable.Loaded(_), _
    -> info_status("")
  }
}

fn info_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("snippets-page__status"),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

fn error_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("snippets-page__status snippets-page__status--error"),
      attribute.attribute("role", "alert"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

fn content_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.page {
    loadable.Loaded(page) ->
      case pagination_model.items(page) {
        [] -> empty_state("You have not created any snippets yet.")
        _ -> snippets_table(page, model.deleting_slug, now)
      }
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) ->
      html.div([attribute.class("snippets-page__content")], [])
  }
}

fn empty_state(message: String) -> Element(Msg) {
  html.div(
    [
      attribute.class("snippets-page__empty"),
      attribute.attribute("role", "status"),
    ],
    [html.p([], [html.text(message)])],
  )
}

fn snippets_table(
  page: pagination_model.CursorPage(snippet_dto.SnippetResponse),
  deleting_slug: option.Option(String),
  now: Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("snippets-table snippets-table--manage")], [
    html.div(
      [attribute.class("snippets-table__head snippets-table__head--manage")],
      [
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Language"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Title"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Visibility"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Updated"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Actions"),
        ]),
      ],
    ),
    html.div([attribute.class("snippets-table__body")], {
      pagination_model.items(page)
      |> list.map(fn(snippet) { snippet_row(snippet, deleting_slug, now) })
    }),
  ])
}

fn snippet_row(
  snippet: snippet_dto.SnippetResponse,
  deleting_slug: option.Option(String),
  now: Timestamp,
) -> Element(Msg) {
  let is_deleting = deleting_slug == option.Some(snippet.slug)

  html.div(
    [attribute.class("snippets-table__row snippets-table__row--manage")],
    [
      snippet_cell_link(
        "snippets-table__cell snippets-table__cell--language",
        "Language",
        route.Public(route.Snippet(snippet.slug)),
        language.name(snippet.data.language),
      ),
      snippet_cell_link(
        "snippets-table__cell snippets-table__cell--title",
        "Title",
        route.Public(route.Snippet(snippet.slug)),
        snippet.data.title,
      ),
      html.span([attribute.class("snippets-table__cell")], [
        html.span([attribute.class("snippets-table__cell-label")], [
          html.text("Visibility"),
        ]),
        html.span([attribute.class("snippets-table__cell-value")], [
          html.text(snippet_model.visibility_to_string(snippet.data.visibility)),
        ]),
      ]),
      snippet_cell_link(
        "snippets-table__cell",
        "Updated",
        route.Public(route.Snippet(snippet.slug)),
        timestamp_helpers.relative_label(snippet.updated_at, now),
      ),
      html.div(
        [attribute.class("snippets-table__cell snippets-table__actions")],
        [
          html.span([attribute.class("snippets-table__cell-label")], [
            html.text("Actions"),
          ]),
          html.div([attribute.class("snippets-table__action-group")], [
            html.a(
              [
                attribute.class("snippets-table__action-link"),
                route.href(route.Public(route.Snippet(snippet.slug))),
              ],
              [html.text("Edit")],
            ),
            html.button(
              [
                attribute.type_("button"),
                attribute.class("snippets-table__action-button"),
                attribute.disabled(is_deleting),
                event.on_click(DeleteClicked(snippet.slug)),
              ],
              [
                html.text(case is_deleting {
                  True -> "Deleting..."
                  False -> "Delete"
                }),
              ],
            ),
          ]),
        ],
      ),
    ],
  )
}

fn delete_confirmation_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(delete_dialog_id),
      attribute.class("app-dialog"),
      attribute.attribute("aria-label", "Delete snippet"),
      event.on("close", decode.success(DeleteDialogClosed)),
    ],
    delete_confirmation_dialog_children(model.pending_delete),
  )
}

fn delete_confirmation_dialog_children(
  pending_delete: option.Option(snippet_dto.SnippetResponse),
) -> List(Element(Msg)) {
  case pending_delete {
    option.Some(snippet) -> [
      html.form([attribute.class("app-dialog__form")], [
        html.div([attribute.class("app-dialog__section")], [
          html.p([attribute.class("app-dialog__label")], [
            html.text("Delete snippet"),
          ]),
          html.p([attribute.class("app-dialog__copy")], [
            html.text("Delete "),
            html.code([], [html.text(snippet.data.title)]),
            html.text("? This action cannot be undone."),
          ]),
        ]),
        html.div([attribute.class("app-dialog__actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              attribute.class(
                "app-dialog__button app-dialog__button--secondary",
              ),
              event.on_click(DeleteCancelled),
            ],
            [html.text("Cancel")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("app-dialog__button app-dialog__button--danger"),
              event.on_click(DeleteConfirmed(snippet.slug)),
            ],
            [html.text("Delete snippet")],
          ),
        ]),
      ]),
    ]
    option.None -> []
  }
}

fn snippet_cell_link(
  class_name: String,
  cell_label: String,
  destination: route.Route,
  value: String,
) -> Element(Msg) {
  html.a([attribute.class(class_name), route.href(destination)], [
    html.span([attribute.class("snippets-table__cell-label")], [
      html.text(cell_label),
    ]),
    html.span([attribute.class("snippets-table__cell-value")], [
      html.text(value),
    ]),
  ])
}

fn pagination_button(label: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class("snippets-page__button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
}

fn navigate_to(
  after: option.Option(String),
  before: option.Option(String),
) -> Effect(Msg) {
  let #(path, query) =
    route.path_and_query(route.Account(route.AccountSnippets(after:, before:)))
  modem.push(path, query, option.None)
}

fn find_loaded_snippet(
  state: loadable.Loadable(
    pagination_model.CursorPage(snippet_dto.SnippetResponse),
  ),
  slug: String,
) -> option.Option(snippet_dto.SnippetResponse) {
  case state {
    loadable.Loaded(page) ->
      case
        page
        |> pagination_model.items
        |> list.find(fn(snippet) { snippet.slug == slug })
      {
        Ok(snippet) -> option.Some(snippet)
        _ -> option.None
      }
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> option.None
  }
}
