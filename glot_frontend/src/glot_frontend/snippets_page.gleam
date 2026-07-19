import gleam/json
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/loadable
import glot_core/page/seo
import glot_core/page/snippets
import glot_core/pagination_model
import glot_core/snippet/snippet_dto
import glot_frontend/api
import glot_frontend/delayed_loading
import glot_frontend/ssr_data
import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub type Model {
  Model(
    page: loadable.Loadable(
      pagination_model.CursorPage(snippet_dto.SnippetResponse),
    ),
    username: option.Option(String),
    request: Request,
    loading_indicator: delayed_loading.State,
  )
}

pub opaque type Request {
  Request(
    after: option.Option(String),
    before: option.Option(String),
    username: option.Option(String),
  )
}

pub fn init(
  after after: option.Option(String),
  before before: option.Option(String),
  username username: option.Option(String),
) -> #(Model, Effect(Msg)) {
  let request = Request(after:, before:, username:)
  case init_from_ssr() {
    option.Some(model) -> #(model, effect.none())
    option.None -> {
      let #(loading_indicator, delay_effect) =
        delayed_loading.start(delayed_loading.idle(), fn(generation) {
          LoadingDelayElapsed(request, generation)
        })
      let model =
        Model(
          page: loadable.Loading,
          username: username,
          request:,
          loading_indicator:,
        )

      #(model, effect.batch([load_page(request), delay_effect]))
    }
  }
}

pub type Msg {
  SnippetsLoaded(Request, api.ApiResponse(snippet_dto.ListSnippetsResponse))
  LoadingDelayElapsed(Request, Int)
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
            loading_indicator: delayed_loading.finish(model.loading_indicator),
          ),
          effect.none(),
        )
        True, api.ApiFailure(error) -> #(
          Model(
            ..model,
            page: loadable.LoadError(api.error_message(error)),
            loading_indicator: delayed_loading.finish(model.loading_indicator),
          ),
          effect.none(),
        )
        True, api.HttpFailure(_) -> #(
          Model(
            ..model,
            page: loadable.LoadError("Could not load snippets."),
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
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  snippets.view(
    to_view_model(model, now),
    delayed_loading.is_visible(model.loading_indicator),
  )
}

pub fn metadata(model: Model, canonical_path: String) -> seo.Metadata {
  seo.snippets(model.username, canonical_path)
}

fn load_page(request: Request) -> Effect(Msg) {
  api.list_public_snippets(
    snippets.public_request(
      after: request.after,
      before: request.before,
      username: request.username,
    ),
    fn(result) { SnippetsLoaded(request, result) },
  )
}

fn init_from_ssr() -> option.Option(Model) {
  case ssr_data.take() {
    "" -> option.None
    raw ->
      case json.parse(raw, snippets.decoder()) {
        Ok(view_model) -> option.Some(from_view_model(view_model))
        Error(_) -> option.None
      }
  }
}

fn from_view_model(view_model: snippets.ViewModel) -> Model {
  Model(
    page: view_model.page,
    username: view_model.username,
    request: Request(
      after: option.None,
      before: option.None,
      username: view_model.username,
    ),
    loading_indicator: delayed_loading.idle(),
  )
}

fn to_view_model(model: Model, now: Timestamp) -> snippets.ViewModel {
  snippets.ViewModel(page: model.page, username: model.username, now: now)
}
