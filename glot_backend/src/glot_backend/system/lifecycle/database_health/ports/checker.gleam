pub type Checker {
  Checker(check: fn() -> Result(Nil, String))
}
