import gleam/json
import gleam/option
import glot_core/page/snippets
import glot_core/pagination_model
import glot_core/snippet/snippet_dto
import glot_frontend/api
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import glot_frontend/ssr_data

pub type Model {
  Model(
    page: pagination_model.CursorPage(snippet_dto.SnippetResponse),
    username: option.Option(String),
    state: snippets.State,
  )
}

pub fn init(
  after after: option.Option(String),
  before before: option.Option(String),
  username username: option.Option(String),
) -> #(Model, Effect(Msg)) {
  case init_from_ssr() {
    option.Some(model) -> #(model, effect.none())
    option.None -> {
      let model =
        Model(
          page: snippets.empty_page(),
          username: username,
          state: snippets.Loading,
        )

      #(model, load_page(after, before, username))
    }
  }
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListSnippetsResponse))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: response.page, state: snippets.Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, state: snippets.Error(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, state: snippets.Error("Could not load snippets.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  snippets.view(to_view_model(model))
}

fn load_page(
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> Effect(Msg) {
  api.list_public_snippets(
    snippets.public_request(after:, before:, username:),
    SnippetsLoaded,
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
    state: view_model.state,
  )
}

fn to_view_model(model: Model) -> snippets.ViewModel {
  snippets.ViewModel(
    page: model.page,
    username: model.username,
    state: model.state,
  )
}
