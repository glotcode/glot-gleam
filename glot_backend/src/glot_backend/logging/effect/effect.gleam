import glot_backend/logging/api_log/effect/algebra as api_log_algebra
import glot_backend/logging/effect/algebra
import glot_backend/logging/page_log/effect/algebra as page_log_algebra
import glot_backend/logging/pageview/effect/algebra as pageview_algebra
import glot_backend/logging/run_log/effect/algebra as run_log_algebra
import glot_backend/system/effect/program_types

pub fn api_log(
  effect: api_log_algebra.ApiLogEffect(next),
) -> program_types.DbEffect(next) {
  program_types.LoggingEffect(algebra.ApiLog(effect))
}

pub fn page_log(
  effect: page_log_algebra.PageLogEffect(next),
) -> program_types.DbEffect(next) {
  program_types.LoggingEffect(algebra.PageLog(effect))
}

pub fn pageview(
  effect: pageview_algebra.PageviewLogEffect(next),
) -> program_types.DbEffect(next) {
  program_types.LoggingEffect(algebra.Pageview(effect))
}

pub fn run_log(
  effect: run_log_algebra.RunLogEffect(next),
) -> program_types.DbEffect(next) {
  program_types.LoggingEffect(algebra.RunLog(effect))
}
