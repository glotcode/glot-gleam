import gleam/list
import gleam/option
import glot_core/route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

type Crumb {
  Crumb(label: String, target: option.Option(route.Route))
}

pub fn is_admin_route(current_route: route.Route) -> Bool {
  case current_route {
    route.Admin
    | route.AdminApiLogs
    | route.AdminApiLog(_)
    | route.AdminRunLogs
    | route.AdminRunLog(_)
    | route.AdminPeriodicJobs
    | route.AdminPeriodicJob(_)
    | route.AdminUsers
    | route.AdminUser(_)
    | route.AdminJobs
    | route.AdminJob(_)
    | route.AdminSnippets
    | route.AdminSnippet(_)
    | route.AdminJobLogs
    | route.AdminJobLog(_)
    | route.AdminConfig
    | route.AdminRateLimits -> True
    _ -> False
  }
}

pub fn wrap(
  current_route current_route: route.Route,
  content content: Element(msg),
) -> Element(msg) {
  let crumbs = breadcrumbs(current_route)

  case crumbs {
    [] -> content
    _ ->
      html.div([], [
        view(crumbs),
        content,
      ])
  }
}

fn breadcrumbs(current_route: route.Route) -> List(Crumb) {
  case current_route {
    route.Admin -> [current("Admin")]
    route.AdminConfig -> [
      link("Admin", route.Admin),
      current("App config"),
    ]
    route.AdminRateLimits -> [
      link("Admin", route.Admin),
      current("Rate limits"),
    ]
    route.AdminPeriodicJobs -> [
      link("Admin", route.Admin),
      current("Periodic jobs"),
    ]
    route.AdminPeriodicJob(_) -> [
      link("Admin", route.Admin),
      link("Periodic jobs", route.AdminPeriodicJobs),
      current("Periodic job detail"),
    ]
    route.AdminUsers -> [
      link("Admin", route.Admin),
      current("Users"),
    ]
    route.AdminUser(_) -> [
      link("Admin", route.Admin),
      link("Users", route.AdminUsers),
      current("User detail"),
    ]
    route.AdminJobs -> [
      link("Admin", route.Admin),
      current("Jobs"),
    ]
    route.AdminJob(_) -> [
      link("Admin", route.Admin),
      link("Jobs", route.AdminJobs),
      current("Job detail"),
    ]
    route.AdminSnippets -> [
      link("Admin", route.Admin),
      current("Snippets"),
    ]
    route.AdminSnippet(_) -> [
      link("Admin", route.Admin),
      link("Snippets", route.AdminSnippets),
      current("Snippet detail"),
    ]
    route.AdminApiLogs -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      current("API logs"),
    ]
    route.AdminApiLog(_) -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      link("API logs", route.AdminApiLogs),
      current("API log detail"),
    ]
    route.AdminRunLogs -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      current("Run logs"),
    ]
    route.AdminRunLog(_) -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      link("Run logs", route.AdminRunLogs),
      current("Run log detail"),
    ]
    route.AdminJobLogs -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      current("Job logs"),
    ]
    route.AdminJobLog(_) -> [
      link("Admin", route.Admin),
      link("Logs", route.Admin),
      link("Job logs", route.AdminJobLogs),
      current("Job log detail"),
    ]
    _ -> []
  }
}

fn view(crumbs: List(Crumb)) -> Element(msg) {
  html.div([attribute.class("admin-breadcrumbs-shell")], [
    html.nav(
      [
        attribute.class("admin-breadcrumbs"),
        attribute.attribute("aria-label", "Admin breadcrumbs"),
      ],
      [
        html.ol(
          [attribute.class("admin-breadcrumbs__list")],
          render_crumbs(crumbs) |> list.flatten,
        ),
      ],
    ),
  ])
}

fn render_crumbs(crumbs: List(Crumb)) -> List(List(Element(msg))) {
  case crumbs {
    [] -> []
    [crumb] -> [[render_crumb(crumb)]]
    [crumb, ..rest] -> [
      [render_crumb(crumb), separator()],
      ..render_crumbs(rest)
    ]
  }
}

fn render_crumb(crumb: Crumb) -> Element(msg) {
  let Crumb(label, target) = crumb

  html.li([attribute.class("admin-breadcrumbs__item")], [
    case target {
      option.Some(target) ->
        html.a(
          [attribute.class("admin-breadcrumbs__link"), route.href(target)],
          [html.text(label)],
        )
      option.None ->
        html.span(
          [
            attribute.class(
              "admin-breadcrumbs__link admin-breadcrumbs__link--current",
            ),
            attribute.attribute("aria-current", "page"),
          ],
          [html.text(label)],
        )
    },
  ])
}

fn separator() -> Element(msg) {
  html.li(
    [
      attribute.class("admin-breadcrumbs__separator"),
      attribute.attribute("aria-hidden", "true"),
    ],
    [html.text("/")],
  )
}

fn link(label: String, target: route.Route) -> Crumb {
  Crumb(label:, target: option.Some(target))
}

fn current(label: String) -> Crumb {
  Crumb(label:, target: option.None)
}
