import gleam/option
import gleam/regexp
import glot_core/contact_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/validation_error
import glot_frontend/api/response as api_response
import glot_frontend/public/contact/command
import glot_frontend/public/contact/message.{
  type Msg, EmailChanged, MessageChanged, SubmissionFinished, SubmittedForm,
  TopicChanged, WebsiteChanged,
}
import glot_frontend/public/contact/model.{
  type Model, Idle, SubmitError, Submitted, Submitting,
}

pub fn init(email: option.Option(EmailAddress)) -> Model {
  model.Model(
    email: email
      |> option.map(email_address_model.to_string)
      |> option.unwrap(""),
    topic: contact_dto.topic_to_string(contact_dto.Privacy),
    message: "",
    website: "",
    status: Idle,
  )
}

pub fn session_loaded(
  model: Model,
  email: option.Option(EmailAddress),
) -> Model {
  case model.email, email {
    "", option.Some(email) ->
      model.Model(..model, email: email_address_model.to_string(email))
    _, _ -> model
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  case msg {
    EmailChanged(value) -> #(
      model.Model(..model, email: value, status: clear_feedback(model.status)),
      command.none(),
    )
    TopicChanged(value) -> #(
      model.Model(..model, topic: value, status: clear_feedback(model.status)),
      command.none(),
    )
    MessageChanged(value) -> #(
      model.Model(..model, message: value, status: clear_feedback(model.status)),
      command.none(),
    )
    WebsiteChanged(value) -> #(
      model.Model(..model, website: value, status: clear_feedback(model.status)),
      command.none(),
    )
    SubmittedForm -> submit(model)
    SubmissionFinished(result) ->
      case result {
        api_response.Success(_) -> #(
          model.Model(..model, message: "", website: "", status: Submitted),
          command.none(),
        )
        api_response.ApiFailure(error) -> #(
          model.Model(
            ..model,
            status: SubmitError(api_response.error_message(error)),
          ),
          command.none(),
        )
        api_response.HttpFailure(_) -> #(
          model.Model(
            ..model,
            status: SubmitError(
              "The message could not be sent. Please try again.",
            ),
          ),
          command.none(),
        )
      }
  }
}

fn submit(model: Model) -> #(Model, command.Command(Msg)) {
  let request =
    contact_dto.ContactRequest(
      email: model.email,
      topic: model.topic,
      message: model.message,
      website: model.website,
    )
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  case contact_dto.validate(request, is_email) {
    Ok(_) -> #(
      model.Model(..model, status: Submitting),
      command.Submit(request, SubmissionFinished),
    )
    Error(error) -> #(
      model.Model(..model, status: SubmitError(validation_error.message(error))),
      command.none(),
    )
  }
}

fn clear_feedback(status: model.Status) -> model.Status {
  case status {
    Submitting -> Submitting
    Idle | Submitted | SubmitError(_) -> Idle
  }
}
