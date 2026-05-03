import gleam/int
import gleam/option
import gleam/result
import gleam/string
import glot_core/admin/auth_config_dto
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
    auth: AuthSection,
    docker_run: DockerRunSection,
    auth_loaded: Bool,
    docker_run_loaded: Bool,
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

pub type AuthSection {
  AuthSection(saved: AuthFields, draft: AuthFields, state: SectionState)
}

pub type AuthFields {
  AuthFields(
    login_token_max_age: String,
    session_token_max_age: String,
    session_cookie_max_age: String,
  )
}

pub type SectionState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  AuthLoaded(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  AuthLoginTokenMaxAgeChanged(String)
  AuthSessionTokenMaxAgeChanged(String)
  AuthSessionCookieMaxAgeChanged(String)
  AuthResetClicked
  AuthSaveClicked
  AuthSaveFinished(api.ApiResponse(auth_config_dto.AuthConfigResponse))
  DockerRunLoaded(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
  DockerRunBaseUrlChanged(String)
  DockerRunAccessTokenChanged(String)
  DockerRunResetClicked
  DockerRunSaveClicked
  DockerRunSaveFinished(
    api.ApiResponse(docker_run_config_dto.DockerRunConfigResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      status: NotLoaded,
      auth: empty_auth_section(),
      docker_run: empty_docker_run_section(),
      auth_loaded: False,
      docker_run_loaded: False,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      effect.batch([load_auth_config(), load_docker_run_config()]),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    AuthLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = auth_fields_from_response(response)
          let next_model =
            Model(
              ..model,
              auth: AuthSection(saved: fields, draft: fields, state: Idle),
              auth_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load auth config.")),
          effect.none(),
        )
      }

    AuthLoginTokenMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, login_token_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionTokenMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, session_token_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthSessionCookieMaxAgeChanged(value) -> #(
      Model(
        ..model,
        auth: AuthSection(
          ..model.auth,
          draft: AuthFields(..model.auth.draft, session_cookie_max_age: value),
          state: Idle,
        ),
      ),
      effect.none(),
    )

    AuthResetClicked -> #(
      Model(
        ..model,
        auth: AuthSection(..model.auth, draft: model.auth.saved, state: Idle),
      ),
      effect.none(),
    )

    AuthSaveClicked ->
      case validate_auth_fields(model.auth.draft) {
        Error(message) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: SaveError(message)),
          ),
          effect.none(),
        )
        Ok(request) -> #(
          Model(..model, auth: AuthSection(..model.auth, state: Saving)),
          api.upsert_admin_auth_config(request, AuthSaveFinished),
        )
      }

    AuthSaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = auth_fields_from_response(response)
          #(
            Model(
              ..model,
              auth: AuthSection(saved: fields, draft: fields, state: Saved),
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            auth: AuthSection(..model.auth, state: SaveError(error.message)),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            auth: AuthSection(
              ..model.auth,
              state: SaveError("Could not save auth config."),
            ),
          ),
          effect.none(),
        )
      }

    DockerRunLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let fields = fields_from_response(response)
          let next_model =
            Model(
              ..model,
              auth: model.auth,
              docker_run: DockerRunSection(
                saved: fields,
                draft: fields,
                state: Idle,
              ),
              docker_run_loaded: True,
            )

          #(
            Model(..next_model, status: loaded_status(next_model)),
            effect.none(),
          )
        }
        api.ApiFailure(error) ->
          case error.code {
            "docker_run_config_not_found" -> #(
              Model(
                ..model,
                docker_run: empty_docker_run_section(),
                docker_run_loaded: True,
                status: loaded_status(
                  Model(
                    ..model,
                    docker_run: empty_docker_run_section(),
                    docker_run_loaded: True,
                  ),
                ),
              ),
              effect.none(),
            )
            _ -> #(
              Model(..model, status: LoadError(error.message)),
              effect.none(),
            )
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
              docker_run: DockerRunSection(
                saved: fields,
                draft: fields,
                state: Saved,
              ),
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
              html.text("App config"),
            ]),
          ]),
        ]),
        status_banner(model.status),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__section-grid")], [
            auth_section_view(model.auth, model.status),
            docker_run_section_view(model.docker_run, model.status),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn auth_section_view(section: AuthSection, status: Status) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty_auth(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Auth"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls login token and session expiration values used by the backend.",
            ),
          ]),
        ]),
        html.div([attribute.class("admin-page__policy-header-actions")], [
          auth_status_badge(section),
        ]),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        text_input(
          label: "Login token max age",
          help: "Seconds before a login token expires.",
          value: section.draft.login_token_max_age,
          on_input: AuthLoginTokenMaxAgeChanged,
        ),
        text_input(
          label: "Session token max age",
          help: "Seconds before a session becomes invalid.",
          value: section.draft.session_token_max_age,
          on_input: AuthSessionTokenMaxAgeChanged,
        ),
        text_input(
          label: "Session cookie max age",
          help: "Seconds used when setting the signed session cookie.",
          value: section.draft.session_cookie_max_age,
          on_input: AuthSessionCookieMaxAgeChanged,
        ),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        auth_section_message(section),
        html.div([attribute.class("admin-page__policy-actions")], [
          html.button(
            [
              attribute.type_("button"),
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
              attribute.disabled(
                section.state == Saving || !is_dirty_auth(section),
              ),
              event.on_click(AuthResetClicked),
            ],
            [html.text("Reset")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__button"),
              attribute.disabled(save_disabled),
              event.on_click(AuthSaveClicked),
            ],
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading configuration..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn docker_run_section_view(
  section: DockerRunSection,
  status: Status,
) -> Element(Msg) {
  let save_disabled =
    status != Ready || section.state == Saving || !is_dirty(section)

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text("Docker run"),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(
              "Controls the base URL and access token used when the backend calls the docker-run service.",
            ),
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
              attribute.class(
                "admin-page__button admin-page__button--secondary",
              ),
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
            [
              html.text(case section.state {
                Saving -> "Saving..."
                _ -> "Save"
              }),
            ],
          ),
        ]),
      ]),
    ],
  )
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
  case
    section.state,
    section.saved == empty_docker_run_fields(),
    is_dirty(section)
  {
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
  let message = case section.state {
    SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    Saving -> option.Some(#("admin-page__policy-status", "Saving changes..."))
    Saved -> option.Some(#("admin-page__policy-status", "Config saved."))
    Idle ->
      case section.saved == empty_docker_run_fields(), is_dirty(section) {
        True, False ->
          option.Some(#(
            "admin-page__policy-status",
            "This section is empty until you save initial values.",
          ))
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

fn auth_status_badge(section: AuthSection) -> Element(Msg) {
  case section.state, is_dirty_auth(section) {
    Idle, False -> html.div([], [])
    _, _ ->
      html.span([attribute.class(auth_status_badge_class(section))], [
        html.text(auth_status_badge_text(section)),
      ])
  }
}

fn auth_status_badge_text(section: AuthSection) -> String {
  case section.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case is_dirty_auth(section) {
        True -> "Unsaved"
        False -> ""
      }
  }
}

fn auth_status_badge_class(section: AuthSection) -> String {
  case section.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving -> "admin-page__version"
    Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case is_dirty_auth(section) {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn auth_section_message(section: AuthSection) -> Element(Msg) {
  let message = case section.state {
    SaveError(message) ->
      option.Some(#(
        "admin-page__policy-status admin-page__policy-status--error",
        message,
      ))
    Saving -> option.Some(#("admin-page__policy-status", "Saving changes..."))
    Saved -> option.Some(#("admin-page__policy-status", "Config saved."))
    Idle -> option.None
  }

  case message {
    option.Some(#(class_name, text)) ->
      html.p([attribute.class(class_name)], [html.text(text)])
    option.None -> html.div([], [])
  }
}

fn load_auth_config() -> Effect(Msg) {
  api.get_admin_auth_config(AuthLoaded)
}

fn load_docker_run_config() -> Effect(Msg) {
  api.get_admin_docker_run_config(DockerRunLoaded)
}

fn auth_fields_from_response(
  response: auth_config_dto.AuthConfigResponse,
) -> AuthFields {
  AuthFields(
    login_token_max_age: int.to_string(response.login_token_max_age),
    session_token_max_age: int.to_string(response.session_token_max_age),
    session_cookie_max_age: int.to_string(response.session_cookie_max_age),
  )
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

fn is_dirty_auth(section: AuthSection) -> Bool {
  section.saved != section.draft
}

fn validate_auth_fields(
  fields: AuthFields,
) -> Result(auth_config_dto.UpsertAuthConfigRequest, String) {
  use login_token_max_age <- result.try(parse_positive_int(
    fields.login_token_max_age,
    "Login token max age must be a positive integer.",
  ))
  use session_token_max_age <- result.try(parse_positive_int(
    fields.session_token_max_age,
    "Session token max age must be a positive integer.",
  ))
  use session_cookie_max_age <- result.try(parse_positive_int(
    fields.session_cookie_max_age,
    "Session cookie max age must be a positive integer.",
  ))

  Ok(auth_config_dto.UpsertAuthConfigRequest(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_cookie_max_age: session_cookie_max_age,
  ))
}

fn parse_positive_int(
  value: String,
  error_message: String,
) -> Result(Int, String) {
  case int.parse(string.trim(value)) {
    Ok(parsed) if parsed > 0 -> Ok(parsed)
    _ -> Error(error_message)
  }
}

fn empty_auth_section() -> AuthSection {
  let fields = empty_auth_fields()
  AuthSection(saved: fields, draft: fields, state: Idle)
}

fn empty_auth_fields() -> AuthFields {
  AuthFields(
    login_token_max_age: "",
    session_token_max_age: "",
    session_cookie_max_age: "",
  )
}

fn empty_docker_run_section() -> DockerRunSection {
  let fields = empty_docker_run_fields()
  DockerRunSection(saved: fields, draft: fields, state: Idle)
}

fn empty_docker_run_fields() -> DockerRunFields {
  DockerRunFields(base_url: "", access_token: "")
}

fn loaded_status(model: Model) -> Status {
  case model.auth_loaded && model.docker_run_loaded {
    True -> Ready
    False -> Loading
  }
}
