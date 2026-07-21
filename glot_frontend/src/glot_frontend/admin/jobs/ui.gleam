import glot_frontend/admin/ui/layout as admin_layout
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
      admin_layout.badge(status_text(status, overdue), admin_layout.DangerTone)
    "running", _ ->
      admin_layout.badge(status_text(status, overdue), admin_layout.WarningTone)
    "pending", True ->
      admin_layout.badge(status_text(status, overdue), admin_layout.DangerTone)
    "pending", False ->
      admin_layout.badge(status_text(status, overdue), admin_layout.InfoTone)
    "done", _ ->
      admin_layout.badge(status_text(status, overdue), admin_layout.SuccessTone)
    _, _ ->
      admin_layout.badge(status_text(status, overdue), admin_layout.NeutralTone)
  }
}
