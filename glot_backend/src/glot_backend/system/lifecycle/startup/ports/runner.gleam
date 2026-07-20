pub type Runner {
  Runner(run: fn() -> Result(#(List(String), List(String)), String))
}
