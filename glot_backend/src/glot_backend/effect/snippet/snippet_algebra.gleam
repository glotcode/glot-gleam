import gleam/option
import glot_backend/effect/error
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet, type Visibility}
import youid/uuid.{type Uuid}

pub type SnippetEffect(next) {
  GetSnippetById(
    id: BitArray,
    next: fn(Result(option.Option(HydratedSnippet), error.DbQueryError)) -> next,
  )
  GetSnippetBySlug(
    slug: String,
    next: fn(Result(option.Option(HydratedSnippet), error.DbQueryError)) -> next,
  )
  ListSnippets(
    visibilities: List(Visibility),
    usernames: List(String),
    user_ids: List(Uuid),
    skip_user_ids: List(Uuid),
    after_slug: option.Option(String),
    before_slug: option.Option(String),
    limit: Int,
    next: fn(Result(List(HydratedSnippet), error.DbQueryError)) -> next,
  )
  DeleteSnippet(
    id: BitArray,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteSnippetsByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateSnippet(
    snippet: Snippet,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateSnippet(
    snippet: Snippet,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: SnippetEffect(a), f: fn(a) -> b) -> SnippetEffect(b) {
  case effect {
    GetSnippetById(id, next) ->
      GetSnippetById(id, next: fn(value) { f(next(value)) })
    GetSnippetBySlug(slug, next) ->
      GetSnippetBySlug(slug, next: fn(value) { f(next(value)) })
    ListSnippets(
      visibilities:,
      usernames:,
      user_ids:,
      skip_user_ids:,
      after_slug:,
      before_slug:,
      limit:,
      next:,
    ) ->
      ListSnippets(
        visibilities: visibilities,
        usernames: usernames,
        user_ids: user_ids,
        skip_user_ids: skip_user_ids,
        after_slug: after_slug,
        before_slug: before_slug,
        limit: limit,
        next: fn(value) { f(next(value)) },
      )
    DeleteSnippet(id, next) ->
      DeleteSnippet(id, next: fn(value) { f(next(value)) })
    DeleteSnippetsByAccountId(account_id: account_id, next: next) ->
      DeleteSnippetsByAccountId(
        account_id: account_id,
        next: fn(value) { f(next(value)) },
      )
    CreateSnippet(snippet, next) ->
      CreateSnippet(snippet, next: fn(value) { f(next(value)) })
    UpdateSnippet(snippet, next) ->
      UpdateSnippet(snippet, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetSnippetByIdEffectName
  GetSnippetBySlugEffectName
  ListSnippetsEffectName
  DeleteSnippetEffectName
  DeleteSnippetsByAccountIdEffectName
  CreateSnippetEffectName
  UpdateSnippetEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetSnippetByIdEffectName -> "get_snippet_by_id"
    GetSnippetBySlugEffectName -> "get_snippet_by_slug"
    ListSnippetsEffectName -> "list_snippets"
    DeleteSnippetEffectName -> "delete_snippet"
    DeleteSnippetsByAccountIdEffectName -> "delete_snippets_by_account_id"
    CreateSnippetEffectName -> "create_snippet"
    UpdateSnippetEffectName -> "update_snippet"
  }
}
