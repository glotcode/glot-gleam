import gleam/option
import glot_core/auth/account_model
import glot_core/auth/user_model
import youid/uuid.{type Uuid}

pub type UserListFilters {
  UserListFilters(
    email: option.Option(String),
    username: option.Option(String),
    id: option.Option(Uuid),
    role: option.Option(user_model.UserRole),
    account_state: option.Option(account_model.AccountState),
    account_tier: option.Option(account_model.AccountTier),
  )
}
