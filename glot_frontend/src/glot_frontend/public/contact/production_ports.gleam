import glot_frontend/api/public
import glot_frontend/public/contact/ports

pub fn new() -> ports.Ports(msg) {
  ports.Ports(submit: public.submit_contact)
}
