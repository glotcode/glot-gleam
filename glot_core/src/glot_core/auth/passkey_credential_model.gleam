import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type PasskeyCredential {
  PasskeyCredential(
    id: Uuid,
    user_id: Uuid,
    credential_id: BitArray,
    cose_key: BitArray,
    sign_count: Int,
    aaguid: BitArray,
    created_at: Timestamp,
    updated_at: Timestamp,
    last_used_at: Option(Timestamp),
  )
}

pub fn mark_used(
  credential: PasskeyCredential,
  sign_count: Int,
  used_at: Timestamp,
) -> PasskeyCredential {
  PasskeyCredential(
    ..credential,
    sign_count: sign_count,
    updated_at: used_at,
    last_used_at: option.Some(used_at),
  )
}
