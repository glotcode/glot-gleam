import glot_core/contact_dto
import glot_frontend/api/response
import lustre/effect.{type Effect}

pub type Ports(msg) {
  Ports(
    submit: fn(contact_dto.ContactRequest, fn(response.Response(Nil)) -> msg) ->
      Effect(msg),
  )
}
