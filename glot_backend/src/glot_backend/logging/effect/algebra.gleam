import glot_backend/logging/api_log/effect/algebra as api_log_algebra
import glot_backend/logging/page_log/effect/algebra as page_log_algebra
import glot_backend/logging/pageview/effect/algebra as pageview_algebra
import glot_backend/logging/run_log/effect/algebra as run_log_algebra

pub type Effect(next) {
  ApiLog(api_log_algebra.ApiLogEffect(next))
  PageLog(page_log_algebra.PageLogEffect(next))
  Pageview(pageview_algebra.PageviewLogEffect(next))
  RunLog(run_log_algebra.RunLogEffect(next))
}

pub type EffectName {
  ApiLogName(api_log_algebra.EffectName)
  PageLogName(page_log_algebra.EffectName)
  PageviewName(pageview_algebra.EffectName)
  RunLogName(run_log_algebra.EffectName)
}

pub fn map(effect: Effect(a), transform: fn(a) -> b) -> Effect(b) {
  case effect {
    ApiLog(effect) -> ApiLog(api_log_algebra.map(effect, transform))
    PageLog(effect) -> PageLog(page_log_algebra.map(effect, transform))
    Pageview(effect) -> Pageview(pageview_algebra.map(effect, transform))
    RunLog(effect) -> RunLog(run_log_algebra.map(effect, transform))
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ApiLogName(name) -> api_log_algebra.effect_name_to_string(name)
    PageLogName(name) -> page_log_algebra.effect_name_to_string(name)
    PageviewName(name) -> pageview_algebra.effect_name_to_string(name)
    RunLogName(name) -> run_log_algebra.effect_name_to_string(name)
  }
}

pub fn effect_name_to_family(name: EffectName) -> String {
  case name {
    ApiLogName(_) -> "api_log"
    PageLogName(_) -> "page_log"
    PageviewName(_) -> "pageview_log"
    RunLogName(_) -> "run_log"
  }
}
