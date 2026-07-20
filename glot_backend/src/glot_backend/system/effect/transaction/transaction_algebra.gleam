import glot_backend/system/effect/program_types
import glot_backend/system/effect/transaction/transaction_program

pub fn map(
  effect: program_types.TransactionEffect(a),
  f: fn(a) -> b,
) -> program_types.TransactionEffect(b) {
  case effect {
    program_types.Run(program:) ->
      program_types.Run(program: transaction_program.map(program, f))
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
