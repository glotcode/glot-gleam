import glot_core/route
import lustre/attribute.{type Attribute}

pub fn href(destination: route.Route) -> Attribute(msg) {
  attribute.href(route.to_string(destination))
}
