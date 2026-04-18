import gleam/dynamic/decode
import gleam/option
import gleam/pair
import glot_core/api_action
import glot_core/language
import glot_core/run
import glot_core/snippet/snippet_model
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  UnsupportedLanguage(String)
  SupportedLanguage(RealModel)
}

pub type RealModel {
  RealModel(
    language: language.Language,
    source_code: String,
    run_state: RunState,
  )
}

pub type RunState {
  Idle
  Running
  Completed(run.RunResult)
  RequestError(String)
}

pub fn init(language: String) -> #(Model, Effect(Msg)) {
  let model = case language.from_string(language) {
    option.Some(lang) ->
      SupportedLanguage(RealModel(
        language: lang,
        source_code: language.example_code(lang),
        run_state: Idle,
      ))
    option.None -> UnsupportedLanguage(language)
  }

  #(model, effect.none())
}

pub type Msg {
  SourceCodeChanged(String)
  RunSubmitted
  RunFinished(api.ApiResponse(run.RunResult))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case model {
    UnsupportedLanguage(_) -> #(model, effect.none())
    SupportedLanguage(model) ->
      update_helper(model, msg)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(model: RealModel, msg: Msg) -> #(RealModel, Effect(Msg)) {
  case msg {
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
  }
}

pub fn view(model: Model) -> Element(Msg) {
  case model {
    UnsupportedLanguage(lang) ->
      html.div([], [html.text("Unsupported language: " <> lang)])
    SupportedLanguage(model) -> view_helper(model)
  }
}

fn view_helper(model: RealModel) -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("New Snippet: " <> language.name(model.language))]),
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
    html.div([], [
      html.button(
        [
          attribute.type_("button"),
          attribute.disabled(model.run_state == Running),
          event.on_click(RunSubmitted),
        ],
        [html.text(run_button_text(model.run_state))],
      ),
    ]),
    run_result_view(model.run_state),
  ])
}

fn run_button_text(run_state: RunState) -> String {
  case run_state {
    Running -> "Running..."
    _ -> "Run"
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
