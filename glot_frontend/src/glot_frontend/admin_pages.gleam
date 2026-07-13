import gleam/time/timestamp.{type Timestamp}
import glot_core/route
import glot_frontend/admin_api_log_page
import glot_frontend/admin_api_logs_page
import glot_frontend/admin_config_page
import glot_frontend/admin_email_template_page
import glot_frontend/admin_email_templates_page
import glot_frontend/admin_job_log_page
import glot_frontend/admin_job_logs_page
import glot_frontend/admin_job_page
import glot_frontend/admin_job_type_policies_page
import glot_frontend/admin_jobs_page
import glot_frontend/admin_page
import glot_frontend/admin_periodic_job_page
import glot_frontend/admin_periodic_jobs_page
import glot_frontend/admin_rate_limits_page
import glot_frontend/admin_run_log_page
import glot_frontend/admin_run_logs_page
import glot_frontend/admin_snippet_page
import glot_frontend/admin_snippets_page
import glot_frontend/admin_user_page
import glot_frontend/admin_users_page
import glot_frontend/app_shell
import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub opaque type Model {
  Model(page_model: PageModel)
}

type PageModel {
  AdminPage(admin_page.Model)
  AdminApiLogsPage(admin_api_logs_page.Model)
  AdminApiLogPage(admin_api_log_page.Model)
  AdminRunLogsPage(admin_run_logs_page.Model)
  AdminRunLogPage(admin_run_log_page.Model)
  AdminPeriodicJobsPage(admin_periodic_jobs_page.Model)
  AdminPeriodicJobPage(admin_periodic_job_page.Model)
  AdminUsersPage(admin_users_page.Model)
  AdminUserPage(admin_user_page.Model)
  AdminJobsPage(admin_jobs_page.Model)
  AdminJobPage(admin_job_page.Model)
  AdminEmailTemplatesPage(admin_email_templates_page.Model)
  AdminEmailTemplatePage(admin_email_template_page.Model)
  AdminSnippetsPage(admin_snippets_page.Model)
  AdminSnippetPage(admin_snippet_page.Model)
  AdminJobLogsPage(admin_job_logs_page.Model)
  AdminJobLogPage(admin_job_log_page.Model)
  AdminConfigPage(admin_config_page.Model)
  AdminRateLimitsPage(admin_rate_limits_page.Model)
  AdminJobTypePoliciesPage(admin_job_type_policies_page.Model)
  EmptyPageModel
}

pub type Msg {
  AdminPageMsg(admin_page.Msg)
  AdminApiLogsPageMsg(admin_api_logs_page.Msg)
  AdminApiLogPageMsg(admin_api_log_page.Msg)
  AdminRunLogsPageMsg(admin_run_logs_page.Msg)
  AdminRunLogPageMsg(admin_run_log_page.Msg)
  AdminPeriodicJobsPageMsg(admin_periodic_jobs_page.Msg)
  AdminPeriodicJobPageMsg(admin_periodic_job_page.Msg)
  AdminUsersPageMsg(admin_users_page.Msg)
  AdminUserPageMsg(admin_user_page.Msg)
  AdminJobsPageMsg(admin_jobs_page.Msg)
  AdminJobPageMsg(admin_job_page.Msg)
  AdminEmailTemplatesPageMsg(admin_email_templates_page.Msg)
  AdminEmailTemplatePageMsg(admin_email_template_page.Msg)
  AdminSnippetsPageMsg(admin_snippets_page.Msg)
  AdminSnippetPageMsg(admin_snippet_page.Msg)
  AdminJobLogsPageMsg(admin_job_logs_page.Msg)
  AdminJobLogPageMsg(admin_job_log_page.Msg)
  AdminConfigPageMsg(admin_config_page.Msg)
  AdminRateLimitsPageMsg(admin_rate_limits_page.Msg)
  AdminJobTypePoliciesPageMsg(admin_job_type_policies_page.Msg)
}

pub fn empty() -> Model {
  Model(EmptyPageModel)
}

pub fn init(
  admin_route: route.AdminRoute,
  is_admin: Bool,
) -> #(Model, Effect(Msg)) {
  let #(page_model, page_effect) = init_page(admin_route, is_admin)
  #(Model(page_model), page_effect)
}

fn init_page(
  admin_route: route.AdminRoute,
  is_admin: Bool,
) -> #(PageModel, Effect(Msg)) {
  case admin_route {
    route.AdminHome -> {
      let #(m, eff) = admin_page.init()
      #(AdminPage(m), effect.map(eff, AdminPageMsg))
    }
    route.AdminApiLogs -> {
      let #(m, eff) = admin_api_logs_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_api_logs_page.ensure_loaded(m).1,
            AdminApiLogsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminApiLogsPage(m),
        effect.batch([effect.map(eff, AdminApiLogsPageMsg), admin_effect]),
      )
    }
    route.AdminApiLog(id) -> {
      let #(m, eff) = admin_api_log_page.init(id)
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_api_log_page.ensure_loaded(m).1, AdminApiLogPageMsg)
        False -> effect.none()
      }
      #(
        AdminApiLogPage(m),
        effect.batch([effect.map(eff, AdminApiLogPageMsg), admin_effect]),
      )
    }
    route.AdminRunLogs -> {
      let #(m, eff) = admin_run_logs_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_run_logs_page.ensure_loaded(m).1,
            AdminRunLogsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminRunLogsPage(m),
        effect.batch([effect.map(eff, AdminRunLogsPageMsg), admin_effect]),
      )
    }
    route.AdminRunLog(id) -> {
      let #(m, eff) = admin_run_log_page.init(id)
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_run_log_page.ensure_loaded(m).1, AdminRunLogPageMsg)
        False -> effect.none()
      }
      #(
        AdminRunLogPage(m),
        effect.batch([effect.map(eff, AdminRunLogPageMsg), admin_effect]),
      )
    }
    route.AdminPeriodicJobs -> {
      let #(m, eff) = admin_periodic_jobs_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_periodic_jobs_page.ensure_loaded(m).1,
            AdminPeriodicJobsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminPeriodicJobsPage(m),
        effect.batch([effect.map(eff, AdminPeriodicJobsPageMsg), admin_effect]),
      )
    }
    route.AdminPeriodicJob(id) -> {
      let #(m, eff) = admin_periodic_job_page.init(id)
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_periodic_job_page.ensure_loaded(m).1,
            AdminPeriodicJobPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminPeriodicJobPage(m),
        effect.batch([effect.map(eff, AdminPeriodicJobPageMsg), admin_effect]),
      )
    }
    route.AdminUsers -> {
      let #(m, eff) = admin_users_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_users_page.ensure_loaded(m).1, AdminUsersPageMsg)
        False -> effect.none()
      }
      #(
        AdminUsersPage(m),
        effect.batch([effect.map(eff, AdminUsersPageMsg), admin_effect]),
      )
    }
    route.AdminUser(id) -> {
      let #(m, eff) = admin_user_page.init(id)
      let admin_effect = case is_admin {
        True -> effect.map(admin_user_page.ensure_loaded(m).1, AdminUserPageMsg)
        False -> effect.none()
      }
      #(
        AdminUserPage(m),
        effect.batch([effect.map(eff, AdminUserPageMsg), admin_effect]),
      )
    }
    route.AdminJobs -> {
      let #(m, eff) = admin_jobs_page.init()
      let admin_effect = case is_admin {
        True -> effect.map(admin_jobs_page.ensure_loaded(m).1, AdminJobsPageMsg)
        False -> effect.none()
      }
      #(
        AdminJobsPage(m),
        effect.batch([effect.map(eff, AdminJobsPageMsg), admin_effect]),
      )
    }
    route.AdminJob(job_id) -> {
      let #(m, eff) = admin_job_page.init(job_id)
      let admin_effect = case is_admin {
        True -> effect.map(admin_job_page.ensure_loaded(m).1, AdminJobPageMsg)
        False -> effect.none()
      }
      #(
        AdminJobPage(m),
        effect.batch([effect.map(eff, AdminJobPageMsg), admin_effect]),
      )
    }
    route.AdminEmailTemplates -> {
      let #(m, eff) = admin_email_templates_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_email_templates_page.ensure_loaded(m).1,
            AdminEmailTemplatesPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminEmailTemplatesPage(m),
        effect.batch([
          effect.map(eff, AdminEmailTemplatesPageMsg),
          admin_effect,
        ]),
      )
    }
    route.AdminEmailTemplate(name) -> {
      let #(m, eff) = admin_email_template_page.init(name)
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_email_template_page.ensure_loaded(m).1,
            AdminEmailTemplatePageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminEmailTemplatePage(m),
        effect.batch([
          effect.map(eff, AdminEmailTemplatePageMsg),
          admin_effect,
        ]),
      )
    }
    route.AdminSnippets -> {
      let #(m, eff) = admin_snippets_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_snippets_page.ensure_loaded(m).1,
            AdminSnippetsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminSnippetsPage(m),
        effect.batch([effect.map(eff, AdminSnippetsPageMsg), admin_effect]),
      )
    }
    route.AdminSnippet(slug) -> {
      let #(m, eff) = admin_snippet_page.init(slug)
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_snippet_page.ensure_loaded(m).1, AdminSnippetPageMsg)
        False -> effect.none()
      }
      #(
        AdminSnippetPage(m),
        effect.batch([effect.map(eff, AdminSnippetPageMsg), admin_effect]),
      )
    }
    route.AdminJobLogs -> {
      let #(m, eff) = admin_job_logs_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_job_logs_page.ensure_loaded(m).1,
            AdminJobLogsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminJobLogsPage(m),
        effect.batch([effect.map(eff, AdminJobLogsPageMsg), admin_effect]),
      )
    }
    route.AdminJobLog(id) -> {
      let #(m, eff) = admin_job_log_page.init(id)
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_job_log_page.ensure_loaded(m).1, AdminJobLogPageMsg)
        False -> effect.none()
      }
      #(
        AdminJobLogPage(m),
        effect.batch([effect.map(eff, AdminJobLogPageMsg), admin_effect]),
      )
    }
    route.AdminConfig -> {
      let #(m, eff) = admin_config_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(admin_config_page.ensure_loaded(m).1, AdminConfigPageMsg)
        False -> effect.none()
      }
      #(
        AdminConfigPage(m),
        effect.batch([effect.map(eff, AdminConfigPageMsg), admin_effect]),
      )
    }
    route.AdminRateLimits -> {
      let #(m, eff) = admin_rate_limits_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_rate_limits_page.ensure_loaded(m).1,
            AdminRateLimitsPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminRateLimitsPage(m),
        effect.batch([effect.map(eff, AdminRateLimitsPageMsg), admin_effect]),
      )
    }
    route.AdminJobTypePolicies -> {
      let #(m, eff) = admin_job_type_policies_page.init()
      let admin_effect = case is_admin {
        True ->
          effect.map(
            admin_job_type_policies_page.ensure_loaded(m).1,
            AdminJobTypePoliciesPageMsg,
          )
        False -> effect.none()
      }
      #(
        AdminJobTypePoliciesPage(m),
        effect.batch([
          effect.map(eff, AdminJobTypePoliciesPageMsg),
          admin_effect,
        ]),
      )
    }
  }
}

pub fn session_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.page_model {
    AdminApiLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_logs_page.ensure_loaded(page_model)
      #(
        Model(AdminApiLogsPage(new_page_model)),
        effect.map(page_effect, AdminApiLogsPageMsg),
      )
    }
    AdminApiLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_log_page.ensure_loaded(page_model)
      #(
        Model(AdminApiLogPage(new_page_model)),
        effect.map(page_effect, AdminApiLogPageMsg),
      )
    }
    AdminRunLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_logs_page.ensure_loaded(page_model)
      #(
        Model(AdminRunLogsPage(new_page_model)),
        effect.map(page_effect, AdminRunLogsPageMsg),
      )
    }
    AdminRunLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_log_page.ensure_loaded(page_model)
      #(
        Model(AdminRunLogPage(new_page_model)),
        effect.map(page_effect, AdminRunLogPageMsg),
      )
    }
    AdminPeriodicJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_jobs_page.ensure_loaded(page_model)
      #(
        Model(AdminPeriodicJobsPage(new_page_model)),
        effect.map(page_effect, AdminPeriodicJobsPageMsg),
      )
    }
    AdminPeriodicJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_job_page.ensure_loaded(page_model)
      #(
        Model(AdminPeriodicJobPage(new_page_model)),
        effect.map(page_effect, AdminPeriodicJobPageMsg),
      )
    }
    AdminUsersPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_users_page.ensure_loaded(page_model)
      #(
        Model(AdminUsersPage(new_page_model)),
        effect.map(page_effect, AdminUsersPageMsg),
      )
    }
    AdminUserPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_user_page.ensure_loaded(page_model)
      #(
        Model(AdminUserPage(new_page_model)),
        effect.map(page_effect, AdminUserPageMsg),
      )
    }
    AdminJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_jobs_page.ensure_loaded(page_model)
      #(
        Model(AdminJobsPage(new_page_model)),
        effect.map(page_effect, AdminJobsPageMsg),
      )
    }
    AdminJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_page.ensure_loaded(page_model)
      #(
        Model(AdminJobPage(new_page_model)),
        effect.map(page_effect, AdminJobPageMsg),
      )
    }
    AdminEmailTemplatesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_templates_page.ensure_loaded(page_model)
      #(
        Model(AdminEmailTemplatesPage(new_page_model)),
        effect.map(page_effect, AdminEmailTemplatesPageMsg),
      )
    }
    AdminEmailTemplatePage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_template_page.ensure_loaded(page_model)
      #(
        Model(AdminEmailTemplatePage(new_page_model)),
        effect.map(page_effect, AdminEmailTemplatePageMsg),
      )
    }
    AdminSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippets_page.ensure_loaded(page_model)
      #(
        Model(AdminSnippetsPage(new_page_model)),
        effect.map(page_effect, AdminSnippetsPageMsg),
      )
    }
    AdminSnippetPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippet_page.ensure_loaded(page_model)
      #(
        Model(AdminSnippetPage(new_page_model)),
        effect.map(page_effect, AdminSnippetPageMsg),
      )
    }
    AdminJobLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_logs_page.ensure_loaded(page_model)
      #(
        Model(AdminJobLogsPage(new_page_model)),
        effect.map(page_effect, AdminJobLogsPageMsg),
      )
    }
    AdminJobLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_log_page.ensure_loaded(page_model)
      #(
        Model(AdminJobLogPage(new_page_model)),
        effect.map(page_effect, AdminJobLogPageMsg),
      )
    }
    AdminConfigPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_config_page.ensure_loaded(page_model)
      #(
        Model(AdminConfigPage(new_page_model)),
        effect.map(page_effect, AdminConfigPageMsg),
      )
    }
    AdminRateLimitsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_rate_limits_page.ensure_loaded(page_model)
      #(
        Model(AdminRateLimitsPage(new_page_model)),
        effect.map(page_effect, AdminRateLimitsPageMsg),
      )
    }
    AdminJobTypePoliciesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_type_policies_page.ensure_loaded(page_model)
      #(
        Model(AdminJobTypePoliciesPage(new_page_model)),
        effect.map(page_effect, AdminJobTypePoliciesPageMsg),
      )
    }

    AdminPage(_) | EmptyPageModel -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    AdminPageMsg(page_msg), AdminPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_page.update(page_model, page_msg)
      let new_model = Model(AdminPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPageMsg))
    }

    AdminApiLogsPageMsg(page_msg), AdminApiLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_logs_page.update(page_model, page_msg)
      let new_model = Model(AdminApiLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminApiLogsPageMsg))
    }

    AdminApiLogPageMsg(page_msg), AdminApiLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_log_page.update(page_model, page_msg)
      let new_model = Model(AdminApiLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminApiLogPageMsg))
    }

    AdminRunLogsPageMsg(page_msg), AdminRunLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_logs_page.update(page_model, page_msg)
      let new_model = Model(AdminRunLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRunLogsPageMsg))
    }

    AdminRunLogPageMsg(page_msg), AdminRunLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_log_page.update(page_model, page_msg)
      let new_model = Model(AdminRunLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRunLogPageMsg))
    }

    AdminPeriodicJobsPageMsg(page_msg), AdminPeriodicJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_jobs_page.update(page_model, page_msg)
      let new_model = Model(AdminPeriodicJobsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPeriodicJobsPageMsg))
    }

    AdminPeriodicJobPageMsg(page_msg), AdminPeriodicJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_job_page.update(page_model, page_msg)
      let new_model = Model(AdminPeriodicJobPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminPeriodicJobPageMsg))
    }

    AdminUsersPageMsg(page_msg), AdminUsersPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_users_page.update(page_model, page_msg)
      let new_model = Model(AdminUsersPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminUsersPageMsg))
    }

    AdminUserPageMsg(page_msg), AdminUserPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_user_page.update(page_model, page_msg)
      let new_model = Model(AdminUserPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminUserPageMsg))
    }

    AdminJobsPageMsg(page_msg), AdminJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_jobs_page.update(page_model, page_msg)
      let new_model = Model(AdminJobsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobsPageMsg))
    }

    AdminJobPageMsg(page_msg), AdminJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_page.update(page_model, page_msg)
      let new_model = Model(AdminJobPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobPageMsg))
    }

    AdminEmailTemplatesPageMsg(page_msg), AdminEmailTemplatesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_templates_page.update(page_model, page_msg)
      let new_model = Model(AdminEmailTemplatesPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminEmailTemplatesPageMsg))
    }

    AdminEmailTemplatePageMsg(page_msg), AdminEmailTemplatePage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_template_page.update(page_model, page_msg)
      let new_model = Model(AdminEmailTemplatePage(new_page_model))
      #(new_model, effect.map(page_effect, AdminEmailTemplatePageMsg))
    }

    AdminSnippetsPageMsg(page_msg), AdminSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippets_page.update(page_model, page_msg)
      let new_model = Model(AdminSnippetsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminSnippetsPageMsg))
    }

    AdminSnippetPageMsg(page_msg), AdminSnippetPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippet_page.update(page_model, page_msg)
      let new_model = Model(AdminSnippetPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminSnippetPageMsg))
    }

    AdminJobLogsPageMsg(page_msg), AdminJobLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_logs_page.update(page_model, page_msg)
      let new_model = Model(AdminJobLogsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobLogsPageMsg))
    }

    AdminJobLogPageMsg(page_msg), AdminJobLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_log_page.update(page_model, page_msg)
      let new_model = Model(AdminJobLogPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobLogPageMsg))
    }

    AdminConfigPageMsg(page_msg), AdminConfigPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_config_page.update(page_model, page_msg)
      let new_model = Model(AdminConfigPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminConfigPageMsg))
    }

    AdminRateLimitsPageMsg(page_msg), AdminRateLimitsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_rate_limits_page.update(page_model, page_msg)
      let new_model = Model(AdminRateLimitsPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminRateLimitsPageMsg))
    }

    AdminJobTypePoliciesPageMsg(page_msg), AdminJobTypePoliciesPage(page_model)
    -> {
      let #(new_page_model, page_effect) =
        admin_job_type_policies_page.update(page_model, page_msg)
      let new_model = Model(AdminJobTypePoliciesPage(new_page_model))
      #(new_model, effect.map(page_effect, AdminJobTypePoliciesPageMsg))
    }

    _, _ -> #(model, effect.none())
  }
}

pub fn view(model: Model, now: Timestamp, is_admin: Bool) -> Element(Msg) {
  case is_admin {
    True -> admin_view(model, now)
    False -> app_shell.not_found_view()
  }
}

fn admin_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.page_model {
    EmptyPageModel -> app_shell.not_found_view()
    AdminPage(page_model) -> {
      admin_page.view(page_model) |> element.map(AdminPageMsg)
    }

    AdminApiLogsPage(page_model) -> {
      admin_api_logs_page.view(page_model, now)
      |> element.map(AdminApiLogsPageMsg)
    }

    AdminApiLogPage(page_model) -> {
      admin_api_log_page.view(page_model)
      |> element.map(AdminApiLogPageMsg)
    }

    AdminRunLogsPage(page_model) -> {
      admin_run_logs_page.view(page_model, now)
      |> element.map(AdminRunLogsPageMsg)
    }

    AdminRunLogPage(page_model) -> {
      admin_run_log_page.view(page_model)
      |> element.map(AdminRunLogPageMsg)
    }

    AdminPeriodicJobsPage(page_model) -> {
      admin_periodic_jobs_page.view(page_model, now)
      |> element.map(AdminPeriodicJobsPageMsg)
    }

    AdminPeriodicJobPage(page_model) -> {
      admin_periodic_job_page.view(page_model, now)
      |> element.map(AdminPeriodicJobPageMsg)
    }

    AdminUsersPage(page_model) -> {
      admin_users_page.view(page_model, now)
      |> element.map(AdminUsersPageMsg)
    }

    AdminUserPage(page_model) -> {
      admin_user_page.view(page_model, now)
      |> element.map(AdminUserPageMsg)
    }

    AdminJobsPage(page_model) -> {
      admin_jobs_page.view(page_model, now)
      |> element.map(AdminJobsPageMsg)
    }

    AdminJobPage(page_model) -> {
      admin_job_page.view(page_model, now)
      |> element.map(AdminJobPageMsg)
    }

    AdminEmailTemplatesPage(page_model) -> {
      admin_email_templates_page.view(page_model)
      |> element.map(AdminEmailTemplatesPageMsg)
    }

    AdminEmailTemplatePage(page_model) -> {
      admin_email_template_page.view(page_model)
      |> element.map(AdminEmailTemplatePageMsg)
    }

    AdminSnippetsPage(page_model) -> {
      admin_snippets_page.view(page_model, now)
      |> element.map(AdminSnippetsPageMsg)
    }

    AdminSnippetPage(page_model) -> {
      admin_snippet_page.view(page_model)
      |> element.map(AdminSnippetPageMsg)
    }

    AdminJobLogsPage(page_model) -> {
      admin_job_logs_page.view(page_model, now)
      |> element.map(AdminJobLogsPageMsg)
    }

    AdminJobLogPage(page_model) -> {
      admin_job_log_page.view(page_model)
      |> element.map(AdminJobLogPageMsg)
    }

    AdminConfigPage(page_model) -> {
      admin_config_page.view(page_model)
      |> element.map(AdminConfigPageMsg)
    }

    AdminRateLimitsPage(page_model) -> {
      admin_rate_limits_page.view(page_model)
      |> element.map(AdminRateLimitsPageMsg)
    }

    AdminJobTypePoliciesPage(page_model) -> {
      admin_job_type_policies_page.view(page_model)
      |> element.map(AdminJobTypePoliciesPageMsg)
    }
  }
}
