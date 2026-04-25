import gleam/option
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type AccountState {
  Active
  ReadOnly
  Suspended
}

pub type AccountTier {
  FreeTier
}

pub type Account {
  Account(
    id: Uuid,
    account_state: AccountState,
    account_state_reason: option.Option(String),
    account_tier: AccountTier,
    delete_job_id: option.Option(Uuid),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub fn set_delete_job_id(
  account: Account,
  delete_job_id: option.Option(Uuid),
  updated_at: Timestamp,
) -> Account {
  Account(..account, delete_job_id: delete_job_id, updated_at: updated_at)
}

pub fn account_state_to_string(account_state: AccountState) -> String {
  case account_state {
    Active -> "active"
    ReadOnly -> "read_only"
    Suspended -> "suspended"
  }
}

pub fn account_state_from_string(
  account_state: String,
) -> option.Option(AccountState) {
  case account_state {
    "active" -> option.Some(Active)
    "read_only" -> option.Some(ReadOnly)
    "suspended" -> option.Some(Suspended)
    _ -> option.None
  }
}

pub fn account_tier_to_string(account_tier: AccountTier) -> String {
  case account_tier {
    FreeTier -> "free"
  }
}

pub fn account_tier_from_string(
  account_tier: String,
) -> option.Option(AccountTier) {
  case account_tier {
    "free" -> option.Some(FreeTier)
    _ -> option.None
  }
}
