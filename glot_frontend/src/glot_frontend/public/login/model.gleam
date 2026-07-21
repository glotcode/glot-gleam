import gleam/option
import glot_core/email/email_address_model
import youid/uuid

pub type Model {
  Model(
    email: String,
    token: String,
    step: Step,
    status: Status,
    passkey_supported: Bool,
    passkey_challenge_id: option.Option(uuid.Uuid),
    passkey_status: PasskeyStatus,
  )
}

pub type Step {
  EnterEmail
  EnterToken(email: email_address_model.EmailAddress)
}

pub type Status {
  Idle
  SendingToken
  LoggingIn
  StatusInfo(message: String)
  StatusError(message: String)
}

pub type PasskeyStatus {
  PasskeyIdle
  StartingPasskey
  WaitingForPasskey
  FinishingPasskey
  PasskeyError(message: String)
}
