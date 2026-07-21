import glot_core/route
import glot_frontend/admin/api_logs/detail_managed as admin_api_log_page
import glot_frontend/admin/api_logs/list_managed as admin_api_logs_page
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/config/page_managed as admin_config_page
import glot_frontend/admin/email_templates/detail_managed as admin_email_template_page
import glot_frontend/admin/email_templates/list_managed as admin_email_templates_page
import glot_frontend/admin/home/page as admin_page
import glot_frontend/admin/job_logs/detail_managed as admin_job_log_page
import glot_frontend/admin/job_logs/list_managed as admin_job_logs_page
import glot_frontend/admin/jobs/list_managed as admin_jobs_page
import glot_frontend/admin/jobs/managed as admin_job_page
import glot_frontend/admin/jobs/policies_managed as admin_job_type_policies_page
import glot_frontend/admin/periodic_jobs/list_managed as admin_periodic_jobs_page
import glot_frontend/admin/periodic_jobs/managed as admin_periodic_job_page
import glot_frontend/admin/rate_limits/managed as admin_rate_limits_page
import glot_frontend/admin/router_message.{
  AdminApiLogPageMsg, AdminApiLogsPageMsg, AdminConfigPageMsg,
  AdminEmailTemplatePageMsg, AdminEmailTemplatesPageMsg, AdminJobLogPageMsg,
  AdminJobLogsPageMsg, AdminJobPageMsg, AdminJobTypePoliciesPageMsg,
  AdminJobsPageMsg, AdminPageMsg, AdminPeriodicJobPageMsg,
  AdminPeriodicJobsPageMsg, AdminRateLimitsPageMsg, AdminRunLogPageMsg,
  AdminRunLogsPageMsg, AdminSnippetPageMsg, AdminSnippetsPageMsg,
  AdminUserPageMsg, AdminUsersPageMsg,
}
import glot_frontend/admin/router_state.{
  type PageModel, AdminApiLogPage, AdminApiLogsPage, AdminConfigPage,
  AdminEmailTemplatePage, AdminEmailTemplatesPage, AdminJobLogPage,
  AdminJobLogsPage, AdminJobPage, AdminJobTypePoliciesPage, AdminJobsPage,
  AdminPage, AdminPeriodicJobPage, AdminPeriodicJobsPage, AdminRateLimitsPage,
  AdminRunLogPage, AdminRunLogsPage, AdminSnippetPage, AdminSnippetsPage,
  AdminUserPage, AdminUsersPage, EmptyPageModel,
}
import glot_frontend/admin/run_logs/detail_managed as admin_run_log_page
import glot_frontend/admin/run_logs/list_managed as admin_run_logs_page
import glot_frontend/admin/snippets/detail_managed as admin_snippet_page
import glot_frontend/admin/snippets/list_managed as admin_snippets_page
import glot_frontend/admin/users/list_managed as admin_users_page
import glot_frontend/admin/users/managed as admin_user_page

pub type Model =
  router_state.Model

pub type Msg =
  router_message.Msg

pub fn empty() -> Model {
  router_state.new(EmptyPageModel)
}

pub fn init(
  admin_route: route.AdminRoute,
  is_admin: Bool,
) -> #(Model, admin_effect.Command(Msg)) {
  let #(page_model, page_command) = init_page(admin_route)
  let model = router_state.new(page_model)
  case is_admin {
    False -> #(model, page_command)
    True -> {
      let #(loaded_model, load_command) = session_loaded(model)
      #(loaded_model, admin_effect.batch([page_command, load_command]))
    }
  }
}

fn init_page(
  admin_route: route.AdminRoute,
) -> #(PageModel, admin_effect.Command(Msg)) {
  case admin_route {
    route.AdminHome -> {
      let #(m, eff) = admin_page.init()
      #(AdminPage(m), admin_effect.map(eff, AdminPageMsg))
    }
    route.AdminApiLogs -> {
      let #(m, eff) = admin_api_logs_page.init()
      #(AdminApiLogsPage(m), admin_effect.map(eff, AdminApiLogsPageMsg))
    }
    route.AdminApiLog(id) -> {
      let #(m, eff) = admin_api_log_page.init(id)
      #(AdminApiLogPage(m), admin_effect.map(eff, AdminApiLogPageMsg))
    }
    route.AdminRunLogs -> {
      let #(m, eff) = admin_run_logs_page.init()
      #(AdminRunLogsPage(m), admin_effect.map(eff, AdminRunLogsPageMsg))
    }
    route.AdminRunLog(id) -> {
      let #(m, eff) = admin_run_log_page.init(id)
      #(AdminRunLogPage(m), admin_effect.map(eff, AdminRunLogPageMsg))
    }
    route.AdminPeriodicJobs -> {
      let #(m, eff) = admin_periodic_jobs_page.init()
      #(
        AdminPeriodicJobsPage(m),
        admin_effect.map(eff, AdminPeriodicJobsPageMsg),
      )
    }
    route.AdminPeriodicJob(id) -> {
      let #(m, eff) = admin_periodic_job_page.init(id)
      #(AdminPeriodicJobPage(m), admin_effect.map(eff, AdminPeriodicJobPageMsg))
    }
    route.AdminUsers -> {
      let #(m, eff) = admin_users_page.init()
      #(AdminUsersPage(m), admin_effect.map(eff, AdminUsersPageMsg))
    }
    route.AdminUser(id) -> {
      let #(m, eff) = admin_user_page.init(id)
      #(AdminUserPage(m), admin_effect.map(eff, AdminUserPageMsg))
    }
    route.AdminJobs -> {
      let #(m, eff) = admin_jobs_page.init()
      #(AdminJobsPage(m), admin_effect.map(eff, AdminJobsPageMsg))
    }
    route.AdminJob(job_id) -> {
      let #(m, eff) = admin_job_page.init(job_id)
      #(AdminJobPage(m), admin_effect.map(eff, AdminJobPageMsg))
    }
    route.AdminEmailTemplates -> {
      let #(m, eff) = admin_email_templates_page.init()
      #(
        AdminEmailTemplatesPage(m),
        admin_effect.map(eff, AdminEmailTemplatesPageMsg),
      )
    }
    route.AdminEmailTemplate(name) -> {
      let #(m, eff) = admin_email_template_page.init(name)
      #(
        AdminEmailTemplatePage(m),
        admin_effect.map(eff, AdminEmailTemplatePageMsg),
      )
    }
    route.AdminSnippets -> {
      let #(m, eff) = admin_snippets_page.init()
      #(AdminSnippetsPage(m), admin_effect.map(eff, AdminSnippetsPageMsg))
    }
    route.AdminSnippet(slug) -> {
      let #(m, eff) = admin_snippet_page.init(slug)
      #(AdminSnippetPage(m), admin_effect.map(eff, AdminSnippetPageMsg))
    }
    route.AdminJobLogs -> {
      let #(m, eff) = admin_job_logs_page.init()
      #(AdminJobLogsPage(m), admin_effect.map(eff, AdminJobLogsPageMsg))
    }
    route.AdminJobLog(id) -> {
      let #(m, eff) = admin_job_log_page.init(id)
      #(AdminJobLogPage(m), admin_effect.map(eff, AdminJobLogPageMsg))
    }
    route.AdminConfig -> {
      let #(m, eff) = admin_config_page.init()
      #(AdminConfigPage(m), admin_effect.map(eff, AdminConfigPageMsg))
    }
    route.AdminRateLimits -> {
      let #(m, eff) = admin_rate_limits_page.init()
      #(AdminRateLimitsPage(m), admin_effect.map(eff, AdminRateLimitsPageMsg))
    }
    route.AdminJobTypePolicies -> {
      let #(m, eff) = admin_job_type_policies_page.init()
      #(
        AdminJobTypePoliciesPage(m),
        admin_effect.map(eff, AdminJobTypePoliciesPageMsg),
      )
    }
  }
}

pub fn session_loaded(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  case router_state.page(model) {
    AdminApiLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_logs_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminApiLogsPage(new_page_model)),
        admin_effect.map(page_effect, AdminApiLogsPageMsg),
      )
    }
    AdminApiLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_log_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminApiLogPage(new_page_model)),
        admin_effect.map(page_effect, AdminApiLogPageMsg),
      )
    }
    AdminRunLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_logs_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminRunLogsPage(new_page_model)),
        admin_effect.map(page_effect, AdminRunLogsPageMsg),
      )
    }
    AdminRunLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_log_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminRunLogPage(new_page_model)),
        admin_effect.map(page_effect, AdminRunLogPageMsg),
      )
    }
    AdminPeriodicJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_jobs_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminPeriodicJobsPage(new_page_model)),
        admin_effect.map(page_effect, AdminPeriodicJobsPageMsg),
      )
    }
    AdminPeriodicJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_job_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminPeriodicJobPage(new_page_model)),
        admin_effect.map(page_effect, AdminPeriodicJobPageMsg),
      )
    }
    AdminUsersPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_users_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminUsersPage(new_page_model)),
        admin_effect.map(page_effect, AdminUsersPageMsg),
      )
    }
    AdminUserPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_user_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminUserPage(new_page_model)),
        admin_effect.map(page_effect, AdminUserPageMsg),
      )
    }
    AdminJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_jobs_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminJobsPage(new_page_model)),
        admin_effect.map(page_effect, AdminJobsPageMsg),
      )
    }
    AdminJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminJobPage(new_page_model)),
        admin_effect.map(page_effect, AdminJobPageMsg),
      )
    }
    AdminEmailTemplatesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_templates_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminEmailTemplatesPage(new_page_model)),
        admin_effect.map(page_effect, AdminEmailTemplatesPageMsg),
      )
    }
    AdminEmailTemplatePage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_template_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminEmailTemplatePage(new_page_model)),
        admin_effect.map(page_effect, AdminEmailTemplatePageMsg),
      )
    }
    AdminSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippets_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminSnippetsPage(new_page_model)),
        admin_effect.map(page_effect, AdminSnippetsPageMsg),
      )
    }
    AdminSnippetPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippet_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminSnippetPage(new_page_model)),
        admin_effect.map(page_effect, AdminSnippetPageMsg),
      )
    }
    AdminJobLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_logs_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminJobLogsPage(new_page_model)),
        admin_effect.map(page_effect, AdminJobLogsPageMsg),
      )
    }
    AdminJobLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_log_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminJobLogPage(new_page_model)),
        admin_effect.map(page_effect, AdminJobLogPageMsg),
      )
    }
    AdminConfigPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_config_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminConfigPage(new_page_model)),
        admin_effect.map(page_effect, AdminConfigPageMsg),
      )
    }
    AdminRateLimitsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_rate_limits_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminRateLimitsPage(new_page_model)),
        admin_effect.map(page_effect, AdminRateLimitsPageMsg),
      )
    }
    AdminJobTypePoliciesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_type_policies_page.ensure_loaded(page_model)
      #(
        router_state.new(AdminJobTypePoliciesPage(new_page_model)),
        admin_effect.map(page_effect, AdminJobTypePoliciesPageMsg),
      )
    }

    AdminPage(_) | EmptyPageModel -> #(model, admin_effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, admin_effect.Command(Msg)) {
  case msg, router_state.page(model) {
    AdminPageMsg(page_msg), AdminPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminPageMsg))
    }

    AdminApiLogsPageMsg(page_msg), AdminApiLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_logs_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminApiLogsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminApiLogsPageMsg))
    }

    AdminApiLogPageMsg(page_msg), AdminApiLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_api_log_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminApiLogPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminApiLogPageMsg))
    }

    AdminRunLogsPageMsg(page_msg), AdminRunLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_logs_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminRunLogsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminRunLogsPageMsg))
    }

    AdminRunLogPageMsg(page_msg), AdminRunLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_run_log_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminRunLogPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminRunLogPageMsg))
    }

    AdminPeriodicJobsPageMsg(page_msg), AdminPeriodicJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_jobs_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminPeriodicJobsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminPeriodicJobsPageMsg))
    }

    AdminPeriodicJobPageMsg(page_msg), AdminPeriodicJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_periodic_job_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminPeriodicJobPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminPeriodicJobPageMsg))
    }

    AdminUsersPageMsg(page_msg), AdminUsersPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_users_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminUsersPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminUsersPageMsg))
    }

    AdminUserPageMsg(page_msg), AdminUserPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_user_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminUserPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminUserPageMsg))
    }

    AdminJobsPageMsg(page_msg), AdminJobsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_jobs_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminJobsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminJobsPageMsg))
    }

    AdminJobPageMsg(page_msg), AdminJobPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminJobPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminJobPageMsg))
    }

    AdminEmailTemplatesPageMsg(page_msg), AdminEmailTemplatesPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_templates_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminEmailTemplatesPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminEmailTemplatesPageMsg))
    }

    AdminEmailTemplatePageMsg(page_msg), AdminEmailTemplatePage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_email_template_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminEmailTemplatePage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminEmailTemplatePageMsg))
    }

    AdminSnippetsPageMsg(page_msg), AdminSnippetsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippets_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminSnippetsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminSnippetsPageMsg))
    }

    AdminSnippetPageMsg(page_msg), AdminSnippetPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_snippet_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminSnippetPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminSnippetPageMsg))
    }

    AdminJobLogsPageMsg(page_msg), AdminJobLogsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_logs_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminJobLogsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminJobLogsPageMsg))
    }

    AdminJobLogPageMsg(page_msg), AdminJobLogPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_job_log_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminJobLogPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminJobLogPageMsg))
    }

    AdminConfigPageMsg(page_msg), AdminConfigPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_config_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminConfigPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminConfigPageMsg))
    }

    AdminRateLimitsPageMsg(page_msg), AdminRateLimitsPage(page_model) -> {
      let #(new_page_model, page_effect) =
        admin_rate_limits_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminRateLimitsPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminRateLimitsPageMsg))
    }

    AdminJobTypePoliciesPageMsg(page_msg), AdminJobTypePoliciesPage(page_model)
    -> {
      let #(new_page_model, page_effect) =
        admin_job_type_policies_page.update(page_model, page_msg)
      let new_model = router_state.new(AdminJobTypePoliciesPage(new_page_model))
      #(new_model, admin_effect.map(page_effect, AdminJobTypePoliciesPageMsg))
    }

    _, _ -> #(model, admin_effect.none())
  }
}
