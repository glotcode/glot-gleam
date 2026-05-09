import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import glot_core/admin/rate_limit_config_dto
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/rate_limit
import glot_frontend/api
import glot_frontend/app_dialog
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const edit_dialog_id = "admin-rate-limits-edit-dialog"

pub type Model {
  Model(
    policies: List(PolicyEditor),
    status: Status,
    active_editor: option.Option(ActiveEditor),
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type PolicyEditor {
  PolicyEditor(
    action: api_action.ApiAction,
    saved_tabs: PolicyTabs,
    draft_tabs: PolicyTabs,
    state: EditorState,
  )
}

pub type PolicyTabs {
  PolicyTabs(anonymous: LimitFields, free: LimitFields, free_plus: LimitFields)
}

pub type LimitFields {
  LimitFields(second: String, minute: String, hour: String, day: String)
}

pub type ActiveEditor {
  ActiveEditor(action: api_action.ApiAction, tab: EditorTab)
}

pub type EditorTab {
  AnonymousTab
  FreeTab
  FreePlusTab
}

pub type EditorState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  PoliciesLoaded(
    api.ApiResponse(rate_limit_config_dto.RateLimitPoliciesResponse),
  )
  EditClicked(api_action.ApiAction)
  EditDialogClosed
  TabSelected(api_action.ApiAction, EditorTab)
  FieldChanged(api_action.ApiAction, EditorTab, rate_limit.TimeUnit, String)
  CancelClicked
  SaveClicked(api_action.ApiAction)
  SaveFinished(
    api_action.ApiAction,
    api.ApiResponse(rate_limit_config_dto.RateLimitPolicyResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(policies: [], status: NotLoaded, active_editor: option.None),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(Model(..model, status: Loading), load_policies())
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    PoliciesLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            policies: ordered_policy_editors(response.policies),
            status: Ready,
            active_editor: option.None,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            status: LoadError("Could not load rate limit policies."),
          ),
          effect.none(),
        )
      }

    EditClicked(action) -> {
      let next_policies =
        update_policy(model.policies, action, fn(policy) {
          PolicyEditor(..policy, draft_tabs: policy.saved_tabs, state: Idle)
        })

      #(
        Model(
          ..model,
          policies: next_policies,
          active_editor: option.Some(ActiveEditor(action:, tab: AnonymousTab)),
        ),
        app_dialog.open(edit_dialog_id),
      )
    }

    EditDialogClosed -> #(
      Model(..model, active_editor: option.None),
      effect.none(),
    )

    TabSelected(action, tab) -> #(
      Model(
        ..model,
        active_editor: option.Some(ActiveEditor(action:, tab: tab)),
      ),
      effect.none(),
    )

    FieldChanged(action, tab, unit, value) -> #(
      Model(
        ..model,
        policies: update_policy(model.policies, action, fn(policy) {
          PolicyEditor(
            ..policy,
            draft_tabs: update_tab_fields(policy.draft_tabs, tab, fn(fields) {
              update_limit_field(fields, unit, value)
            }),
            state: Idle,
          )
        }),
      ),
      effect.none(),
    )

    CancelClicked -> #(
      Model(..model, active_editor: option.None),
      app_dialog.close(edit_dialog_id),
    )

    SaveClicked(action) ->
      case find_policy(model.policies, action) {
        option.None -> #(model, effect.none())
        option.Some(policy) ->
          case policy_to_request(policy) {
            Ok(request) -> #(
              Model(
                ..model,
                policies: update_policy(model.policies, action, fn(row) {
                  PolicyEditor(..row, state: Saving)
                }),
              ),
              api.upsert_admin_rate_limit_policy(request, fn(result) {
                SaveFinished(action, result)
              }),
            )
            Error(message) -> #(
              Model(
                ..model,
                policies: update_policy(model.policies, action, fn(row) {
                  PolicyEditor(..row, state: SaveError(message))
                }),
              ),
              effect.none(),
            )
          }
      }

    SaveFinished(action, result) ->
      case result {
        api.ApiSuccess(response) -> {
          let saved_tabs = policy_tabs_from_rules(response.rules)

          #(
            Model(
              ..model,
              policies: update_policy(model.policies, action, fn(policy) {
                PolicyEditor(
                  ..policy,
                  saved_tabs: saved_tabs,
                  draft_tabs: saved_tabs,
                  state: Saved,
                )
              }),
              active_editor: option.None,
            ),
            app_dialog.close(edit_dialog_id),
          )
        }

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            policies: update_policy(model.policies, action, fn(policy) {
              PolicyEditor(..policy, state: SaveError(error.message))
            }),
          ),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            policies: update_policy(model.policies, action, fn(policy) {
              PolicyEditor(
                ..policy,
                state: SaveError("Could not save rate limit policy."),
              )
            }),
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
              html.text("Admin rate limits"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Each action shows its current limits. Edit opens a compact modal.",
              ),
            ]),
          ]),
        ]),
        status_banner(model.status),
        policies_view(model),
      ]),
    ]),
    edit_dialog(model),
  ])
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading policies..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn policies_view(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("admin-page__policies")],
    list.map(model.policies, policy_summary_view),
  )
}

fn policy_summary_view(policy: PolicyEditor) -> Element(Msg) {
  html.article([attribute.class("admin-page__policy")], [
    html.div([attribute.class("admin-page__policy-header")], [
      html.div([], [
        html.h3([attribute.class("admin-page__policy-title")], [
          html.text(action_label(policy.action)),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy-header-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button admin-page__button--secondary"),
            event.on_click(EditClicked(policy.action)),
          ],
          [html.text("Edit")],
        ),
      ]),
    ]),
    summary_rows(policy.saved_tabs),
  ])
}

fn summary_rows(tabs: PolicyTabs) -> Element(Msg) {
  case tabs_is_empty(tabs) {
    True ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No limits"),
      ])
    False ->
      html.div([attribute.class("admin-page__summary")], [
        html.div(
          [
            attribute.class(
              "admin-page__summary-row admin-page__summary-row--head",
            ),
          ],
          [
            html.span([attribute.class("admin-page__summary-label")], [
              html.text("Tier"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Second"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Minute"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Hour"),
            ]),
            html.span([attribute.class("admin-page__summary-unit")], [
              html.text("Day"),
            ]),
          ],
        ),
        summary_row("Anonymous", tabs.anonymous),
        summary_row("Free", tabs.free),
        summary_row("FreePlus", tabs.free_plus),
      ])
  }
}

fn summary_row(label: String, fields: LimitFields) -> Element(Msg) {
  html.div([attribute.class("admin-page__summary-row")], [
    html.span([attribute.class("admin-page__summary-label")], [
      html.text(label),
    ]),
    summary_value(fields.second),
    summary_value(fields.minute),
    summary_value(fields.hour),
    summary_value(fields.day),
  ])
}

fn summary_value(value: String) -> Element(Msg) {
  html.span([attribute.class("admin-page__summary-value")], [
    html.text(case value {
      "" -> "-"
      _ -> value
    }),
  ])
}

fn edit_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(edit_dialog_id),
      attribute.class("app-dialog admin-page__dialog"),
      event.on("close", decode.success(EditDialogClosed)),
    ],
    [
      case active_policy(model) {
        option.Some(#(policy, ActiveEditor(action:, tab: active_tab))) ->
          edit_dialog_form(policy, action, active_tab)
        option.None -> html.div([], [])
      },
    ],
  )
}

fn edit_dialog_form(
  policy: PolicyEditor,
  action: api_action.ApiAction,
  active_tab: EditorTab,
) -> Element(Msg) {
  let active_fields = tab_fields(policy.draft_tabs, active_tab)

  html.form(
    [
      attribute.class("app-dialog__form"),
      event.on_submit(fn(_) { SaveClicked(action) }),
    ],
    [
      html.div([attribute.class("app-dialog__section")], [
        html.div([attribute.class("admin-page__dialog-header")], [
          html.div([], [
            html.p([attribute.class("app-dialog__label")], [
              html.text(action_label(action)),
            ]),
            html.p([attribute.class("app-dialog__copy")], [
              html.text(
                "Leave an input empty to remove that limit for the selected tab.",
              ),
            ]),
          ]),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("admin-page__dialog-close"),
              event.on_click(CancelClicked),
            ],
            [html.text("Close")],
          ),
        ]),
        tab_buttons(action, active_tab),
        html.div([attribute.class("admin-page__modal-grid")], [
          unit_input(
            action,
            active_tab,
            rate_limit.Second,
            "Per second",
            active_fields.second,
          ),
          unit_input(
            action,
            active_tab,
            rate_limit.Minute,
            "Per minute",
            active_fields.minute,
          ),
          unit_input(
            action,
            active_tab,
            rate_limit.Hour,
            "Per hour",
            active_fields.hour,
          ),
          unit_input(
            action,
            active_tab,
            rate_limit.Day,
            "Per day",
            active_fields.day,
          ),
        ]),
        modal_status(policy),
      ]),
      html.div([attribute.class("app-dialog__actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class("app-dialog__button app-dialog__button--secondary"),
            event.on_click(CancelClicked),
          ],
          [html.text("Cancel")],
        ),
        html.button(
          [
            attribute.type_("submit"),
            attribute.class("app-dialog__button"),
            attribute.disabled(policy.state == Saving),
          ],
          [html.text("Save")],
        ),
      ]),
    ],
  )
}

fn tab_buttons(
  action: api_action.ApiAction,
  active_tab: EditorTab,
) -> Element(Msg) {
  html.div([attribute.class("admin-page__tab-row")], [
    tab_button(action, AnonymousTab, active_tab, "Anonymous"),
    tab_button(action, FreeTab, active_tab, "Free"),
    tab_button(action, FreePlusTab, active_tab, "FreePlus"),
  ])
}

fn tab_button(
  action: api_action.ApiAction,
  tab: EditorTab,
  active_tab: EditorTab,
  label: String,
) -> Element(Msg) {
  let class_name = case tab == active_tab {
    True -> "admin-page__chip admin-page__chip--selected"
    False -> "admin-page__chip"
  }

  html.button(
    [
      attribute.type_("button"),
      attribute.class(class_name),
      event.on_click(TabSelected(action, tab)),
    ],
    [html.text(label)],
  )
}

fn unit_input(
  action: api_action.ApiAction,
  tab: EditorTab,
  unit: rate_limit.TimeUnit,
  label: String,
  value: String,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [
      html.text(label),
    ]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      event.on_input(fn(next) { FieldChanged(action, tab, unit, next) }),
    ]),
  ])
}

fn active_policy(model: Model) -> option.Option(#(PolicyEditor, ActiveEditor)) {
  case model.active_editor {
    option.Some(active) ->
      case find_policy(model.policies, active.action) {
        option.Some(policy) -> option.Some(#(policy, active))
        option.None -> option.None
      }
    option.None -> option.None
  }
}

fn load_policies() -> Effect(Msg) {
  api.get_admin_rate_limit_policies(PoliciesLoaded)
}

fn ordered_policy_editors(
  policies: List(rate_limit_config_dto.RateLimitPolicyResponse),
) -> List(PolicyEditor) {
  build_policies(api_action.list(), policies)
}

fn build_policies(
  actions: List(api_action.ApiAction),
  responses: List(rate_limit_config_dto.RateLimitPolicyResponse),
) -> List(PolicyEditor) {
  case actions {
    [] -> []
    [action, ..rest] -> [
      policy_editor_from_response(
        action,
        find_policy_response(responses, action),
      ),
      ..build_policies(rest, responses)
    ]
  }
}

fn policy_editor_from_response(
  action: api_action.ApiAction,
  response: option.Option(rate_limit_config_dto.RateLimitPolicyResponse),
) -> PolicyEditor {
  case response {
    option.Some(response) -> {
      let tabs = policy_tabs_from_rules(response.rules)
      PolicyEditor(
        action: action,
        saved_tabs: tabs,
        draft_tabs: tabs,
        state: Idle,
      )
    }
    option.None -> {
      let tabs = empty_policy_tabs()
      PolicyEditor(
        action: action,
        saved_tabs: tabs,
        draft_tabs: tabs,
        state: Idle,
      )
    }
  }
}

fn policy_tabs_from_rules(
  rules: List(rate_limit_config_dto.RateLimitRule),
) -> PolicyTabs {
  list.fold(rules, empty_policy_tabs(), fn(tabs, rule) {
    let fields = limit_fields_from_limits(rule.limits)

    case rule.match {
      rate_limit_config_dto.AnonymousMatch ->
        PolicyTabs(..tabs, anonymous: fields)
      rate_limit_config_dto.AuthenticatedMatch(account_tiers) ->
        case account_tiers {
          [account_model.FreeTier] -> PolicyTabs(..tabs, free: fields)
          [account_model.FreePlusTier] -> PolicyTabs(..tabs, free_plus: fields)
          _ -> tabs
        }
    }
  })
}

fn empty_policy_tabs() -> PolicyTabs {
  PolicyTabs(
    anonymous: empty_limit_fields(),
    free: empty_limit_fields(),
    free_plus: empty_limit_fields(),
  )
}

fn empty_limit_fields() -> LimitFields {
  LimitFields(second: "", minute: "", hour: "", day: "")
}

fn limit_fields_from_limits(limits: List(rate_limit.RateLimit)) -> LimitFields {
  list.fold(limits, empty_limit_fields(), fn(fields, limit) {
    let value = int.to_string(limit.max_requests)
    case limit.unit {
      rate_limit.Second -> LimitFields(..fields, second: value)
      rate_limit.Minute -> LimitFields(..fields, minute: value)
      rate_limit.Hour -> LimitFields(..fields, hour: value)
      rate_limit.Day -> LimitFields(..fields, day: value)
    }
  })
}

fn policy_to_request(
  policy: PolicyEditor,
) -> Result(rate_limit_config_dto.UpsertRateLimitPolicyRequest, String) {
  let rules =
    []
    |> append_rule_from_tab(AnonymousTab, policy.draft_tabs.anonymous)
    |> append_rule_from_tab(FreeTab, policy.draft_tabs.free)
    |> append_rule_from_tab(FreePlusTab, policy.draft_tabs.free_plus)

  case rules {
    [] ->
      Error(
        "Add at least one limit in Anonymous, Free, or FreePlus before saving.",
      )
    _ ->
      Ok(rate_limit_config_dto.UpsertRateLimitPolicyRequest(
        action: policy.action,
        rules: rules,
      ))
  }
}

fn append_rule_from_tab(
  rules: List(rate_limit_config_dto.RateLimitRule),
  tab: EditorTab,
  fields: LimitFields,
) -> List(rate_limit_config_dto.RateLimitRule) {
  case limits_from_fields(fields) {
    Ok([]) -> rules
    Ok(limits) -> list.append(rules, [rate_limit_rule(tab, limits)])
    Error(_) -> rules
  }
}

fn rate_limit_rule(
  tab: EditorTab,
  limits: List(rate_limit.RateLimit),
) -> rate_limit_config_dto.RateLimitRule {
  let rule_match = case tab {
    AnonymousTab -> rate_limit_config_dto.AnonymousMatch
    FreeTab ->
      rate_limit_config_dto.AuthenticatedMatch(account_tiers: [
        account_model.FreeTier,
      ])
    FreePlusTab ->
      rate_limit_config_dto.AuthenticatedMatch(account_tiers: [
        account_model.FreePlusTier,
      ])
  }

  rate_limit_config_dto.RateLimitRule(match: rule_match, limits: limits)
}

fn limits_from_fields(
  fields: LimitFields,
) -> Result(List(rate_limit.RateLimit), String) {
  use second <- result.try(optional_limit(
    fields.second,
    rate_limit.Second,
    "Per second",
  ))
  use minute <- result.try(optional_limit(
    fields.minute,
    rate_limit.Minute,
    "Per minute",
  ))
  use hour <- result.try(optional_limit(
    fields.hour,
    rate_limit.Hour,
    "Per hour",
  ))
  use day <- result.try(optional_limit(fields.day, rate_limit.Day, "Per day"))

  Ok(
    []
    |> append_optional_limit(second)
    |> append_optional_limit(minute)
    |> append_optional_limit(hour)
    |> append_optional_limit(day),
  )
}

fn optional_limit(
  value: String,
  unit: rate_limit.TimeUnit,
  label: String,
) -> Result(option.Option(rate_limit.RateLimit), String) {
  case value {
    "" -> Ok(option.None)
    _ ->
      case int.parse(value) {
        Ok(max_requests) if max_requests > 0 ->
          Ok(
            option.Some(rate_limit.RateLimit(unit:, max_requests: max_requests)),
          )
        Ok(_) -> Error(label <> " must be greater than 0.")
        Error(_) -> Error(label <> " must be a whole number.")
      }
  }
}

fn append_optional_limit(
  limits: List(rate_limit.RateLimit),
  maybe_limit: option.Option(rate_limit.RateLimit),
) -> List(rate_limit.RateLimit) {
  case maybe_limit {
    option.Some(limit) -> list.append(limits, [limit])
    option.None -> limits
  }
}

fn update_tab_fields(
  tabs: PolicyTabs,
  tab: EditorTab,
  update: fn(LimitFields) -> LimitFields,
) -> PolicyTabs {
  case tab {
    AnonymousTab -> PolicyTabs(..tabs, anonymous: update(tabs.anonymous))
    FreeTab -> PolicyTabs(..tabs, free: update(tabs.free))
    FreePlusTab -> PolicyTabs(..tabs, free_plus: update(tabs.free_plus))
  }
}

fn update_limit_field(
  fields: LimitFields,
  unit: rate_limit.TimeUnit,
  value: String,
) -> LimitFields {
  case unit {
    rate_limit.Second -> LimitFields(..fields, second: value)
    rate_limit.Minute -> LimitFields(..fields, minute: value)
    rate_limit.Hour -> LimitFields(..fields, hour: value)
    rate_limit.Day -> LimitFields(..fields, day: value)
  }
}

fn tab_fields(tabs: PolicyTabs, tab: EditorTab) -> LimitFields {
  case tab {
    AnonymousTab -> tabs.anonymous
    FreeTab -> tabs.free
    FreePlusTab -> tabs.free_plus
  }
}

fn tabs_is_empty(tabs: PolicyTabs) -> Bool {
  fields_is_empty(tabs.anonymous)
  && fields_is_empty(tabs.free)
  && fields_is_empty(tabs.free_plus)
}

fn fields_is_empty(fields: LimitFields) -> Bool {
  fields.second == ""
  && fields.minute == ""
  && fields.hour == ""
  && fields.day == ""
}

fn is_dirty(policy: PolicyEditor) -> Bool {
  policy.draft_tabs != policy.saved_tabs
}

fn editor_status_text(state: EditorState, dirty: Bool) -> String {
  case state {
    Idle ->
      case dirty {
        True -> "Unsaved changes."
        False -> "In sync."
      }
    Saving -> "Saving..."
    Saved -> "Saved."
    SaveError(message) -> message
  }
}

fn editor_status_class(state: EditorState, dirty: Bool) -> String {
  case state {
    SaveError(_) -> "admin-page__policy-status admin-page__policy-status--error"
    Idle ->
      case dirty {
        True -> "admin-page__policy-status admin-page__policy-status--dirty"
        False -> "admin-page__policy-status"
      }
    Saving | Saved -> "admin-page__policy-status"
  }
}

fn modal_status(policy: PolicyEditor) -> Element(Msg) {
  let dirty = is_dirty(policy)

  case policy.state, dirty {
    Idle, False -> html.div([], [])
    _, _ ->
      html.p([attribute.class(editor_status_class(policy.state, dirty))], [
        html.text(editor_status_text(policy.state, dirty)),
      ])
  }
}

fn find_policy(
  policies: List(PolicyEditor),
  action: api_action.ApiAction,
) -> option.Option(PolicyEditor) {
  list.find(policies, fn(policy) { policy.action == action })
  |> option.from_result()
}

fn find_policy_response(
  responses: List(rate_limit_config_dto.RateLimitPolicyResponse),
  action: api_action.ApiAction,
) -> option.Option(rate_limit_config_dto.RateLimitPolicyResponse) {
  list.find(responses, fn(response) { response.action == action })
  |> option.from_result()
}

fn update_policy(
  policies: List(PolicyEditor),
  action: api_action.ApiAction,
  update: fn(PolicyEditor) -> PolicyEditor,
) -> List(PolicyEditor) {
  list.map(policies, fn(policy) {
    case policy.action == action {
      True -> update(policy)
      False -> policy
    }
  })
}

fn action_label(action: api_action.ApiAction) -> String {
  case action {
    api_action.TrackPageviewAction -> "Track pageview"
    api_action.RunAction -> "Run code"
    api_action.GetLanguageVersionAction -> "Get language version"
    api_action.GetSessionAction -> "Get session"
    api_action.LogoutAction -> "Logout"
    api_action.GetAccountAction -> "Get account"
    api_action.UpdateAccountAction -> "Update account"
    api_action.ScheduleDeleteAccountAction -> "Schedule account deletion"
    api_action.CancelDeleteAccountAction -> "Cancel account deletion"
    api_action.GetSnippetAction -> "Get snippet"
    api_action.ListPublicSnippetsAction -> "List public snippets"
    api_action.ListSessionSnippetsAction -> "List account snippets"
    api_action.CreateSnippetAction -> "Create snippet"
    api_action.UpdateSnippetAction -> "Update snippet"
    api_action.DeleteSnippetAction -> "Delete snippet"
    api_action.SendLoginTokenAction -> "Send login token"
    api_action.LoginAction -> "Login"
    api_action.GetAdminDebugConfigAction -> "Get debug config"
    api_action.UpsertAdminDebugConfigAction -> "Save debug config"
    api_action.GetAdminAuthConfigAction -> "Get auth config"
    api_action.UpsertAdminAuthConfigAction -> "Save auth config"
    api_action.GetAdminCleanupConfigAction -> "Get cleanup config"
    api_action.UpsertAdminCleanupConfigAction -> "Save cleanup config"
    api_action.GetAdminPeriodicJobsAction -> "Get periodic jobs"
    api_action.GetAdminPeriodicJobAction -> "Get periodic job"
    api_action.UpdateAdminPeriodicJobAction -> "Save periodic job"
    api_action.GetAdminJobsAction -> "Get admin jobs"
    api_action.GetAdminJobAction -> "Get admin job"
    api_action.CreateAdminJobAction -> "Create admin job"
    api_action.GetAdminUsersAction -> "Get admin users"
    api_action.GetAdminUserAction -> "Get admin user"
    api_action.UpdateAdminUserAction -> "Update admin user"
    api_action.GetAdminApiLogsAction -> "Get API logs"
    api_action.GetAdminApiLogAction -> "Get API log"
    api_action.GetAdminJobLogsAction -> "Get job logs"
    api_action.GetAdminJobLogAction -> "Get job log"
    api_action.GetAdminRateLimitPoliciesAction -> "Get admin rate limits"
    api_action.UpsertAdminRateLimitPolicyAction -> "Save admin rate limits"
    api_action.GetAdminDockerRunConfigAction -> "Get docker run config"
    api_action.UpsertAdminDockerRunConfigAction -> "Save docker run config"
  }
}
