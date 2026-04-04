pub type TransactionEffect(next) {
  Run(program: next)
}

pub fn map(
  effect: TransactionEffect(a),
  f: fn(a) -> b,
) -> TransactionEffect(b) {
  case effect {
    Run(program:) -> Run(program: f(program))
  }
}

pub type EffectName {
  RunEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    RunEffectName -> "run"
  }
}

