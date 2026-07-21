import gleam/option
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/platform/json
import lustre/element.{type Element}

pub fn optional_raw_block(
  title title: String,
  value value: option.Option(String),
) -> Element(msg) {
  admin_layout.named_code_block(
    title:,
    value: json.optional_pretty_print_json_or_none(value),
  )
}
