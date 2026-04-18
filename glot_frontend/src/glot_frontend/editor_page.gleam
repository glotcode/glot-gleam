import gleam/dynamic/decode
import gleam/option
import gleam/pair
import glot_core/api_action
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_frontend/api
import glot_frontend/route
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

pub type Model {
  UnsupportedLanguage(String)
  LoadingSnippet(String)
  LoadError(String)
  SupportedLanguage(RealModel)
}

pub type RealModel {
  RealModel(
    slug: option.Option(String),
    language: language.Language,
    source_code: String,
    run_state: RunState,
    save_state: SaveState,
  )
}

pub type RunState {
  Idle
  Running
  Completed(run.RunResult)
  RequestError(String)
}

pub type SaveState {
  SaveIdle
  Saving
  Saved(slug: String)
  SaveError(String)
}

pub fn init_new(language: String) -> #(Model, Effect(Msg)) {
  let model = case language.from_string(language) {
    option.Some(lang) ->
      SupportedLanguage(RealModel(
        slug: option.None,
        language: lang,
        source_code: language.example_code(lang),
        run_state: Idle,
        save_state: SaveIdle,
      ))
    option.None -> UnsupportedLanguage(language)
  }

  #(model, effect.none())
}

pub fn init_existing(slug: String) -> #(Model, Effect(Msg)) {
  #(
    LoadingSnippet(slug),
    api.get_snippet(snippet_dto.GetSnippetRequest(slug: slug), SnippetLoaded),
  )
}

pub type Msg {
  SnippetLoaded(api.ApiResponse(snippet_dto.SnippetResponse))
  SourceCodeChanged(String)
  RunSubmitted
  RunFinished(api.ApiResponse(run.RunResult))
  SaveSubmitted
  SaveFinished(api.ApiResponse(snippet_dto.SnippetResponse))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model, msg {
    LoadingSnippet(_), SnippetLoaded(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let files = response.data.files
          let source_code = case files {
            [snippet_model.File(content:, ..), ..] -> content
            [] -> ""
          }

          #(
            SupportedLanguage(RealModel(
              slug: option.Some(response.slug),
              language: response.data.language,
              source_code: source_code,
              run_state: Idle,
              save_state: SaveIdle,
            )),
            effect.none(),
          )
        }

        api.ApiFailure(error) -> #(LoadError(error.message), effect.none())

        api.HttpFailure(_) ->
          #(LoadError("Could not load snippet."), effect.none())
      }
    }

    UnsupportedLanguage(_), _ -> #(model, effect.none())
    LoadingSnippet(_), _ -> #(model, effect.none())
    LoadError(_), _ -> #(model, effect.none())
    SupportedLanguage(model), _ ->
      update_helper(model, msg)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(model: RealModel, msg: Msg) -> #(RealModel, Effect(Msg)) {
  case msg {
    SnippetLoaded(_) -> #(model, effect.none())

    SourceCodeChanged(source_code) -> #(
      RealModel(..model, source_code: source_code),
      effect.none(),
    )

    RunSubmitted -> {
      let request =
        run.RunRequest(
          image: language.container_image(model.language),
          payload: run.RunRequestPayload(
            run_instructions: language.run_instructions(
              model.language,
              language.default_filename(model.language),
              [],
            ),
            files: [
              snippet_model.File(
                name: language.default_filename(model.language),
                content: model.source_code,
              ),
            ],
            stdin: option.None,
          ),
        )

      #(
        RealModel(..model, run_state: Running),
        api.run_code(request, RunFinished),
      )
    }

    RunFinished(result) -> {
      case result {
        api.ApiSuccess(run_result) -> #(
          RealModel(..model, run_state: Completed(run_result)),
          effect.none(),
        )

        api.ApiFailure(error) -> #(
          RealModel(..model, run_state: RequestError(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          RealModel(
            ..model,
            run_state: RequestError(
              "Could not complete "
              <> api_action.to_string(api_action.RunAction)
              <> ".",
            ),
          ),
          effect.none(),
        )
      }
    }

    SaveSubmitted -> {
      let run_instructions =
        language.run_instructions(
          model.language,
          language.default_filename(model.language),
          [],
        )

      let request =
        snippet_dto.CreateSnippetRequest(
          data: snippet_dto.SnippetData(
            title: "",
            language: model.language,
            visibility: snippet_model.Unlisted,
            stdin: "",
            run_command: run_instructions.run_command,
            files: [
              snippet_model.File(
                name: language.default_filename(model.language),
                content: model.source_code,
              ),
            ],
          ),
        )

      let effect = case model.slug {
        option.Some(slug) ->
          api.update_snippet(
            snippet_dto.UpdateSnippetRequest(slug: slug, data: request.data),
            SaveFinished,
          )

        option.None ->
          api.create_snippet(request, SaveFinished)
      }

      #(RealModel(..model, save_state: Saving), effect)
    }

    SaveFinished(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          let next_model = RealModel(..model, save_state: Saved(response.slug))
          case model.slug {
            option.Some(_) -> #(next_model, effect.none())
            option.None -> {
              let navigate =
                modem.push(
                  route.to_string(route.Snippet(response.slug)),
                  option.None,
                  option.None,
                )
              #(next_model, navigate)
            }
          }
        }

        api.ApiFailure(error) -> #(
          RealModel(..model, save_state: SaveError(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          RealModel(
            ..model,
            save_state: SaveError(
              "Could not complete "
              <> api_action.to_string(api_action.CreateSnippetAction)
              <> ".",
            ),
          ),
          effect.none(),
        )
      }
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model {
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
    LoadingSnippet(_slug) ->
      html.div([], [html.text("Loading snippet...")])
    LoadError(message) ->
      html.div([], [html.text(message)])
    SupportedLanguage(model) -> view_helper(model)
  }
}

fn view_helper(model: RealModel) -> Element(Msg) {
  let title = case model.slug {
    option.Some(slug) -> "Snippet: " <> slug
    option.None -> "New Snippet: " <> language.name(model.language)
  }

  html.div([], [
    html.h2([], [html.text(title)]),
    html.div([], [
      element.element(
        "glot-codemirror",
        [
          attribute.attribute("language", language.to_string(model.language)),
          attribute.attribute("value", model.source_code),
          event.on("change", {
            use value <- decode.subfield(["detail", "value"], decode.string)
            decode.success(SourceCodeChanged(value))
          }),
        ],
        [],
      ),
    ]),
    html.div([], action_buttons(model)),
    save_result_view(model.slug, model.save_state),
    run_result_view(model.run_state),
  ])
}

fn action_buttons(model: RealModel) -> List(Element(Msg)) {
  let run_button =
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(model.run_state == Running),
        event.on_click(RunSubmitted),
      ],
      [html.text(run_button_text(model.run_state))],
    )

  let save_button =
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(model.save_state == Saving),
        event.on_click(SaveSubmitted),
      ],
      [html.text(save_button_text(model.save_state))],
    )

  [run_button, save_button]
}

fn run_button_text(run_state: RunState) -> String {
  case run_state {
    Running -> "Running..."
    _ -> "Run"
  }
}

fn save_button_text(save_state: SaveState) -> String {
  case save_state {
    Saving -> "Saving..."
    _ -> "Save"
  }
}

fn save_result_view(_slug: option.Option(String), save_state: SaveState) -> Element(Msg) {
  case save_state {
    SaveIdle -> html.div([], [])

    Saving -> html.p([], [html.text("Saving snippet...")])

    Saved(slug) -> html.p([], [html.text("Saved snippet: " <> slug)])

    SaveError(message) ->
      html.div([], [
        html.h3([], [html.text("Save failed")]),
        html.pre([], [html.text(message)]),
      ])
  }
}

fn run_result_view(run_state: RunState) -> Element(Msg) {
  case run_state {
    Idle -> html.div([], [])

    Running -> html.p([], [html.text("Running snippet...")])

    RequestError(message) ->
      html.div([], [
        html.h3([], [html.text("Run failed")]),
        html.pre([], [html.text(message)]),
      ])

    Completed(result) ->
      case result {
        Ok(success) ->
          html.div([], [
            html.h3([], [html.text("Output")]),
            output_block("stdout", success.stdout),
            output_block("stderr", success.stderr),
            output_block("error", success.error),
          ])

        Error(failure) ->
          html.div([], [
            html.h3([], [html.text("Run failed")]),
            html.pre([], [html.text(failure.message)]),
          ])
      }
  }
}

fn output_block(label: String, content: String) -> Element(Msg) {
  case content == "" {
    True -> html.div([], [])
    False ->
      html.div([], [
        html.h4([], [html.text(label)]),
        html.pre([], [html.text(content)]),
      ])
  }
}
