import gleam/option
import glot_core/admin/docker_run_config_dto
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    status: Status,
    docker_run: DockerRunSection,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type DockerRunSection {
  DockerRunSection(
    saved: DockerRunFields,
    draft: DockerRunFields,
    state: SectionState,
  )
}

pub type DockerRunFields {
  DockerRunFields(base_url: String, access_token: String)
}

pub type SectionState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  DockerRunLoaded(api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse))
  DockerRunBaseUrlChanged(String)
  DockerRunAccessTokenChanged(String)
  DockerRunResetClicked
  DockerRunSaveClicked
  DockerRunSaveFinished(api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(status: NotLoaded, docker_run: empty_docker_run_section()),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded ->
      #(Model(..model, status: Loading), load_docker_run_config())
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    DockerRunLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = fields_from_response(response)
          #(
            Model(
              status: Ready,
              docker_run: DockerRunSection(saved: fields, draft: fields, state: Idle),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) ->
          case error.code {
            "docker_run_config_not_found" -> #(
              Model(status: Ready, docker_run: empty_docker_run_section()),
              effect.none(),
            )
            _ -> #(Model(..model, status: LoadError(error.message)), effect.none())
          }
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load docker run config.")),
          effect.none(),
        )
      }

    DockerRunBaseUrlChanged(value) -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: DockerRunFields(..model.docker_run.draft, base_url: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunAccessTokenChanged(value) -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: DockerRunFields(..model.docker_run.draft, access_token: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunResetClicked -> #(
      Model(
        ..model,
        docker_run: DockerRunSection(
          ..model.docker_run,
          draft: model.docker_run.saved,
          state: Idle,
        ),
      ),
      effect.none(),
    )

    DockerRunSaveClicked ->
      case validate_docker_run_fields(model.docker_run.draft) {
        Error(message) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError(message),
            ),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(..model.docker_run, state: Saving),
          ),
          api.upsert_admin_docker_run_config(request, DockerRunSaveFinished),
        )
      }

    DockerRunSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = fields_from_response(response)
          #(
            Model(
              ..model,
              docker_run: DockerRunSection(saved: fields, draft: fields, state: Saved),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError(error.message),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            docker_run: DockerRunSection(
              ..model.docker_run,
              state: SaveError("Could not save docker run config."),
            ),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Admin config"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text("Operational settings live here. More sections can be added without changing the page structure."),
            ]),
          ]),
        ]),
        status_banner(model.status),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Configuration"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Sections on this page are editable runtime settings backed by app config."),
            ]),
          ]),
          html.div([attribute.class("admin-page__section-grid")], [
            docker_run_section_view(model.docker_run, model.status),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading configuration..."),
      ])
    LoadError(message) ->
      html.p(
        [attribute.class("admin-page__status admin-page__status--error")],
        [html.text(message)],
      )
  }
}

fn docker_run_section_view(
  section: DockerRunSection,
  status: Status,
) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty(section)

  html.article([attribute.class("admin-page__policy admin-page__policy--config")], [
    html.div([attribute.class("admin-page__policy-header")], [
      html.div([], [
        html.h3([attribute.class("admin-page__policy-title")], [
          html.text("Docker run"),
        ]),
        html.p([attribute.class("admin-page__policy-subtitle")], [
          html.text("Controls the base URL and access token used when the backend calls the docker-run service."),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy-header-actions")], [
        status_badge(section),
      ]),
    ]),
    html.div([attribute.class("admin-page__field-grid")], [
      text_input(
        label: "Base URL",
        help: "Example: https://docker-run.internal",
        value: section.draft.base_url,
        on_input: DockerRunBaseUrlChanged,
      ),
      text_input(
        label: "Access token",
        help: "Stored as a regular app config value.",
        value: section.draft.access_token,
        on_input: DockerRunAccessTokenChanged,
      ),
    ]),
    html.div([attribute.class("admin-page__policy-footer")], [
      section_message(section),
      html.div([attribute.class("admin-page__policy-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button admin-page__button--secondary"),
            attribute.disabled(section.state == Saving || !is_dirty(section)),
            event.on_click(DockerRunResetClicked),
          ],
          [html.text("Reset")],
        ),
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button"),
            attribute.disabled(save_disabled),
            event.on_click(DockerRunSaveClicked),
          ],
          [html.text(case section.state {
            Saving -> "Saving..."
            _ -> "Save"
          })],
        ),
      ]),
    ]),
  ])
}

fn text_input(
  label label: String,
  help help: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [
      html.text(label),
    ]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      event.on_input(on_input),
    ]),
    html.span([attribute.class("admin-page__field-help")], [
      html.text(help),
    ]),
  ])
}

fn status_badge(section: DockerRunSection) -> Element(Msg) {
  case section.state, section.saved == empty_docker_run_fields(), is_dirty(section) {
    Idle, False, False -> html.div([], [])
    _, _, _ ->
      html.span([attribute.class(status_badge_class(section))], [
        html.text(status_badge_text(section)),
      ])
  }
}

fn status_badge_text(section: DockerRunSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False -> "Not configured"
        _, True -> "Unsaved"
        _, False -> ""
      }
  }
}

fn status_badge_class(section: DockerRunSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False -> "admin-page__version"
        _, True -> "admin-page__version admin-page__version--dirty"
        _, False -> "admin-page__version"
      }
  }
}

fn section_message(section: DockerRunSection) -> Element(Msg) {
  let message =
    case section.state {
      SaveError(message) -> option.Some(#("admin-page__policy-status admin-page__policy-status--error", message))
      Saving ->
        option.Some(#("admin-page__policy-status", "Saving changes..."))
      Saved ->
        option.Some(#("admin-page__policy-status", "Config saved."))
      Idle ->
        case section.saved == empty_docker_run_fields(), is_dirty(section) {
          True, False ->
            option.Some(#("admin-page__policy-status", "This section is empty until you save initial values."))
          _, True -> option.None
          _, False -> option.None
        }
    }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn load_docker_run_config() -> Effect(Msg) {
  api.get_admin_docker_run_config(DockerRunLoaded)
}

fn fields_from_response(
  response: docker_run_config_dto.DockerRunConfigResponse,
) -> DockerRunFields {
  DockerRunFields(
    base_url: response.base_url,
    access_token: response.access_token,
  )
}

fn validate_docker_run_fields(
  fields: DockerRunFields,
) -> Result(docker_run_config_dto.UpsertDockerRunConfigRequest, String) {
  case fields.base_url, fields.access_token {
    "", _ -> Error("Base URL must not be empty.")
    _, "" -> Error("Access token must not be empty.")
    _, _ ->
      Ok(docker_run_config_dto.UpsertDockerRunConfigRequest(
        base_url: fields.base_url,
        access_token: fields.access_token,
      ))
  }
}

fn is_dirty(section: DockerRunSection) -> Bool {
  section.saved != section.draft
}

fn empty_docker_run_section() -> DockerRunSection {
  let fields = empty_docker_run_fields()
  DockerRunSection(saved: fields, draft: fields, state: Idle)
}

fn empty_docker_run_fields() -> DockerRunFields {
  DockerRunFields(base_url: "", access_token: "")
}
