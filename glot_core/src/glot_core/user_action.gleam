import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/api_action.{type ApiAction}
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub type UserAction {
  UserAction(
    id: Uuid,
    request_id: Uuid,
    action: ApiAction,
    ip: Option(String),
    user_id: Option(Uuid),
    created_at: Timestamp,
  )
}

pub type UserActionFilter {
  UserActionFilter(
    windows: List(rate_limit.Window),
    action: ApiAction,
    count_by: CountBy,
  )
}

pub type CountBy {
  CountByIp(String)
  CountByUser(Uuid)
}
