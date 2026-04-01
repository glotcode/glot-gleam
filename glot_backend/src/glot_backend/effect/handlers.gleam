import glot_backend/context
import glot_backend/effect
import glot_backend/effect/handlers_builder
import glot_backend/effect/transaction/transaction_handlers

pub fn from_context(ctx: context.Context) -> effect.Handlers {
  handlers_builder.from_context(
    ctx,
    fn(programs) {
      transaction_handlers.run_in_transaction(ctx, programs)
    },
  )
}
