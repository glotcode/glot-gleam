import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type PasskeyChallengeFlow {
  PasskeyRegistrationChallenge
  PasskeyAuthenticationChallenge
}

pub type PasskeyChallenge {
  PasskeyChallenge(
    id: Uuid,
    user_id: Option(Uuid),
    flow: PasskeyChallengeFlow,
    challenge_state: BitArray,
    created_at: Timestamp,
    expires_at: Timestamp,
  )
}

pub fn flow_to_string(flow: PasskeyChallengeFlow) -> String {
  case flow {
    PasskeyRegistrationChallenge -> "registration"
    PasskeyAuthenticationChallenge -> "authentication"
  }
}

pub fn flow_from_string(value: String) -> Option(PasskeyChallengeFlow) {
  case value {
    "registration" -> option.Some(PasskeyRegistrationChallenge)
    "authentication" -> option.Some(PasskeyAuthenticationChallenge)
    _ -> option.None
  }
}
