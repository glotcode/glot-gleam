import glot_frontend/admin_ui
import lustre/element.{type Element}

pub fn status_text(status: String, overdue: Bool) -> String {
  case status, overdue {
    "pending", True -> "Pending • overdue"
    "pending", False -> "Pending"
    "running", _ -> "Running"
    "failed", _ -> "Failed"
    "done", _ -> "Done"
    value, _ -> value
  }
}

pub fn status_badge(status: String, overdue: Bool) -> Element(msg) {
  case status, overdue {
    "failed", _ ->
      admin_ui.badge(status_text(status, overdue), admin_ui.DangerTone)
    "running", _ ->
      admin_ui.badge(status_text(status, overdue), admin_ui.WarningTone)
    "pending", True ->
      admin_ui.badge(status_text(status, overdue), admin_ui.DangerTone)
    "pending", False ->
      admin_ui.badge(status_text(status, overdue), admin_ui.InfoTone)
    "done", _ ->
      admin_ui.badge(status_text(status, overdue), admin_ui.SuccessTone)
    _, _ -> admin_ui.badge(status_text(status, overdue), admin_ui.NeutralTone)
  }
}
