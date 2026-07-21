import glot_core/contact_dto
import glot_frontend/api/response

pub type Command(msg) {
  None
  Submit(contact_dto.ContactRequest, fn(response.Response(Nil)) -> msg)
}

pub fn none() -> Command(msg) {
  None
}
