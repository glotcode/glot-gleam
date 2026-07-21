pub type Model {
  Model(
    email: String,
    topic: String,
    message: String,
    website: String,
    status: Status,
  )
}

pub type Status {
  Idle
  Submitting
  Submitted
  SubmitError(String)
}
