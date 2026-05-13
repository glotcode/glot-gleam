import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_core/admin/job_type_policy_dto
import glot_frontend/admin_format
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/loadable
import glot_frontend/mutation
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(policies: loadable.Loadable(List(PolicyEditor)))
}

pub type PolicyEditor {
  PolicyEditor(
    job_type: String,
    saved: PolicyFields,
    draft: PolicyFields,
    state: mutation.MutationState,
  )
}

pub type PolicyFields {
  PolicyFields(
    max_attempts: String,
    timeout_seconds: String,
    base_backoff_seconds: String,
    max_backoff_seconds: String,
  )
}

pub type Field {
  MaxAttemptsField
  TimeoutSecondsField
  BaseBackoffSecondsField
  MaxBackoffSecondsField
}

pub type Msg {
  PoliciesLoaded(
    api.ApiResponse(job_type_policy_dto.ListJobTypePoliciesResponse),
  )
  FieldChanged(String, Field, String)
  ResetClicked(String)
  SaveClicked(String)
  SaveFinished(
    String,
    api.ApiResponse(job_type_policy_dto.JobTypePolicyResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(policies: loadable.NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.policies,
      api.get_admin_job_type_policies(PoliciesLoaded),
    )
  {
    #(policies, next_effect) -> #(Model(policies: policies), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    PoliciesLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            policies: loadable.Loaded(list.map(
              response.policies,
              editor_from_response,
            )),
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(policies: loadable.LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(policies: loadable.LoadError(
            "Could not load job type policies.",
          )),
          effect.none(),
        )
      }

    FieldChanged(job_type, field, value) -> #(
      Model(
        policies: loadable.Loaded(
          update_editor(loaded_policies(model), job_type, fn(editor) {
            PolicyEditor(
              ..editor,
              draft: update_field(editor.draft, field, value),
              state: mutation.clear_feedback(editor.state),
            )
          }),
        ),
      ),
      effect.none(),
    )

    ResetClicked(job_type) -> #(
      Model(
        policies: loadable.Loaded(
          update_editor(loaded_policies(model), job_type, fn(editor) {
            PolicyEditor(..editor, draft: editor.saved, state: mutation.Idle)
          }),
        ),
      ),
      effect.none(),
    )

    SaveClicked(job_type) ->
      case find_editor(loaded_policies(model), job_type) {
        option.None -> #(model, effect.none())
        option.Some(editor) ->
          case request_from_editor(editor) {
            Ok(request) -> #(
              Model(
                policies: loadable.Loaded(
                  update_editor(loaded_policies(model), job_type, fn(current) {
                    PolicyEditor(..current, state: mutation.Saving)
                  }),
                ),
              ),
              api.upsert_admin_job_type_policy(request, fn(result) {
                SaveFinished(job_type, result)
              }),
            )
            Error(message) -> #(
              Model(
                policies: loadable.Loaded(
                  update_editor(loaded_policies(model), job_type, fn(current) {
                    PolicyEditor(..current, state: mutation.SaveError(message))
                  }),
                ),
              ),
              effect.none(),
            )
          }
      }

    SaveFinished(job_type, result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            policies: loadable.Loaded(
              update_editor(loaded_policies(model), job_type, fn(_) {
                let editor = editor_from_response(response)
                PolicyEditor(..editor, state: mutation.Saved)
              }),
            ),
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(
            policies: loadable.Loaded(
              update_editor(loaded_policies(model), job_type, fn(editor) {
                PolicyEditor(..editor, state: mutation.SaveError(error.message))
              }),
            ),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            policies: loadable.Loaded(
              update_editor(loaded_policies(model), job_type, fn(editor) {
                PolicyEditor(
                  ..editor,
                  state: mutation.SaveError("Could not save job type policy."),
                )
              }),
            ),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page(
    title: "Job type policies",
    intro: "Tune queue retry and timeout defaults per job type. New jobs inherit these values when they are enqueued.",
    content: [
      admin_ui.loadable_status(model.policies, "Loading job type policies..."),
      policies_content(model),
    ],
  )
}

fn policies_content(model: Model) -> Element(Msg) {
  loadable.fold(
    model.policies,
    admin_ui.empty_state("No job type policies were returned."),
    admin_ui.empty_state("Loading job type policies..."),
    fn(policies) {
      case policies {
        [] -> admin_ui.empty_state("No job type policies were returned.")
        _ ->
          html.div(
            [attribute.class("admin-page__section-grid")],
            list.map(policies, policy_card),
          )
      }
    },
    fn(_) { admin_ui.empty_state("No job type policies were returned.") },
  )
}

fn policy_card(editor: PolicyEditor) -> Element(Msg) {
  let dirty = editor.draft != editor.saved
  let save_disabled = mutation.is_saving(editor.state) || !dirty

  html.article(
    [attribute.class("admin-page__policy admin-page__policy--config")],
    [
      html.div([attribute.class("admin-page__policy-header")], [
        html.div([], [
          html.h3([attribute.class("admin-page__policy-title")], [
            html.text(job_type_label(editor.job_type)),
          ]),
          html.p([attribute.class("admin-page__policy-subtitle")], [
            html.text(editor.job_type),
          ]),
        ]),
        badge_for_editor(editor, dirty),
      ]),
      html.div([attribute.class("admin-page__field-grid")], [
        admin_ui.text_input(
          label: "Max attempts",
          help: "Retry limit for new jobs of this type.",
          value: editor.draft.max_attempts,
          placeholder: "3",
          on_input: fn(value) {
            FieldChanged(editor.job_type, MaxAttemptsField, value)
          },
        ),
        admin_ui.text_input(
          label: "Timeout seconds",
          help: "Maximum execution time before the job fails.",
          value: editor.draft.timeout_seconds,
          placeholder: "60",
          on_input: fn(value) {
            FieldChanged(editor.job_type, TimeoutSecondsField, value)
          },
        ),
        admin_ui.text_input(
          label: "Base backoff",
          help: "Initial retry delay in seconds.",
          value: editor.draft.base_backoff_seconds,
          placeholder: "10",
          on_input: fn(value) {
            FieldChanged(editor.job_type, BaseBackoffSecondsField, value)
          },
        ),
        admin_ui.text_input(
          label: "Max backoff",
          help: "Maximum retry delay in seconds.",
          value: editor.draft.max_backoff_seconds,
          placeholder: "300",
          on_input: fn(value) {
            FieldChanged(editor.job_type, MaxBackoffSecondsField, value)
          },
        ),
      ]),
      html.div([attribute.class("admin-page__policy-footer")], [
        admin_ui.mutation_status(
          editor.state,
          "Saving job type policy...",
          "Job type policy saved.",
        ),
        html.div([attribute.class("admin-page__actions")], [
          admin_ui.secondary_button(
            [
              attribute.type_("button"),
              attribute.disabled(mutation.is_saving(editor.state) || !dirty),
              event.on_click(ResetClicked(editor.job_type)),
            ],
            "Reset",
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class(admin_ui.primary_button_class()),
              attribute.disabled(save_disabled),
              event.on_click(SaveClicked(editor.job_type)),
            ],
            [html.text(save_button_text(editor.state))],
          ),
        ]),
      ]),
    ],
  )
}

fn badge_for_editor(editor: PolicyEditor, dirty: Bool) -> Element(Msg) {
  case editor.state {
    mutation.SaveError(_) -> admin_ui.badge("Error", admin_ui.DangerTone)
    mutation.Saving -> admin_ui.badge("Saving", admin_ui.InfoTone)
    mutation.Saved -> admin_ui.badge("Saved", admin_ui.SuccessTone)
    mutation.Idle ->
      case dirty {
        True -> admin_ui.badge("Unsaved", admin_ui.WarningTone)
        False -> html.div([], [])
      }
  }
}

fn save_button_text(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save policy"
  }
}

fn editor_from_response(
  response: job_type_policy_dto.JobTypePolicyResponse,
) -> PolicyEditor {
  let fields = fields_from_response(response)

  PolicyEditor(
    job_type: response.job_type,
    saved: fields,
    draft: fields,
    state: mutation.Idle,
  )
}

fn fields_from_response(
  response: job_type_policy_dto.JobTypePolicyResponse,
) -> PolicyFields {
  PolicyFields(
    max_attempts: int.to_string(response.max_attempts),
    timeout_seconds: int.to_string(response.timeout_seconds),
    base_backoff_seconds: int.to_string(response.base_backoff_seconds),
    max_backoff_seconds: int.to_string(response.max_backoff_seconds),
  )
}

fn request_from_editor(
  editor: PolicyEditor,
) -> Result(job_type_policy_dto.UpsertJobTypePolicyRequest, String) {
  use max_attempts <- result.try(admin_format.parse_positive_int(
    editor.draft.max_attempts,
    "Max attempts",
  ))
  use timeout_seconds <- result.try(admin_format.parse_positive_int(
    editor.draft.timeout_seconds,
    "Timeout seconds",
  ))
  use base_backoff_seconds <- result.try(admin_format.parse_positive_int(
    editor.draft.base_backoff_seconds,
    "Base backoff",
  ))
  use max_backoff_seconds <- result.try(admin_format.parse_positive_int(
    editor.draft.max_backoff_seconds,
    "Max backoff",
  ))

  case base_backoff_seconds > max_backoff_seconds {
    True -> Error("Base backoff must be less than or equal to max backoff.")
    False ->
      Ok(job_type_policy_dto.UpsertJobTypePolicyRequest(
        job_type: editor.job_type,
        max_attempts: max_attempts,
        timeout_seconds: timeout_seconds,
        base_backoff_seconds: base_backoff_seconds,
        max_backoff_seconds: max_backoff_seconds,
      ))
  }
}

fn update_editor(
  editors: List(PolicyEditor),
  job_type: String,
  update: fn(PolicyEditor) -> PolicyEditor,
) -> List(PolicyEditor) {
  list.map(editors, fn(editor) {
    case editor.job_type == job_type {
      True -> update(editor)
      False -> editor
    }
  })
}

fn find_editor(
  editors: List(PolicyEditor),
  job_type: String,
) -> option.Option(PolicyEditor) {
  editors
  |> list.filter(fn(editor) { editor.job_type == job_type })
  |> list.first
  |> option.from_result()
}

fn update_field(
  fields: PolicyFields,
  field: Field,
  value: String,
) -> PolicyFields {
  case field {
    MaxAttemptsField -> PolicyFields(..fields, max_attempts: value)
    TimeoutSecondsField -> PolicyFields(..fields, timeout_seconds: value)
    BaseBackoffSecondsField ->
      PolicyFields(..fields, base_backoff_seconds: value)
    MaxBackoffSecondsField -> PolicyFields(..fields, max_backoff_seconds: value)
  }
}

fn loaded_policies(model: Model) -> List(PolicyEditor) {
  case model.policies {
    loadable.Loaded(policies) -> policies
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> []
  }
}

fn job_type_label(job_type: String) -> String {
  job_type
  |> string.replace(each: "_", with: " ")
}
