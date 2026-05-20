@external(erlang, "base64url_ffi", "encode")
pub fn encode(_value: BitArray) -> String {
  panic as "not implemented"
}

@external(erlang, "base64url_ffi", "decode")
pub fn decode(_value: String) -> Result(BitArray, String) {
  panic as "not implemented"
}
