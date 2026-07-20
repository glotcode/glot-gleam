-- name: GetPasskeyCredentialByCredentialId :one
SELECT
  id,
  user_id,
  credential_id,
  cose_key,
  sign_count,
  aaguid,
  os_name,
  browser_name,
  user_agent,
  created_at,
  updated_at,
  last_used_at
FROM passkey_credentials
WHERE credential_id = $1;

-- name: ListPasskeyCredentialsByUserId :many
SELECT
  id,
  user_id,
  credential_id,
  cose_key,
  sign_count,
  aaguid,
  os_name,
  browser_name,
  user_agent,
  created_at,
  updated_at,
  last_used_at
FROM passkey_credentials
WHERE user_id = $1
ORDER BY created_at ASC;

-- name: GetPasskeyChallengeById :one
SELECT
  id,
  user_id,
  flow,
  challenge_state,
  created_at,
  expires_at
FROM passkey_challenges
WHERE id = $1;

-- name: InsertPasskeyCredential :exec
INSERT INTO passkey_credentials (id, user_id, credential_id, cose_key, sign_count, aaguid, os_name, browser_name, user_agent, created_at, updated_at, last_used_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12);

-- name: InsertPasskeyChallenge :exec
INSERT INTO passkey_challenges (id, user_id, flow, challenge_state, created_at, expires_at) VALUES ($1, $2, $3, $4, $5, $6);

-- name: UpdatePasskeyCredential :exec
UPDATE passkey_credentials
SET user_id = $1,
    credential_id = $2,
    cose_key = $3,
    sign_count = $4,
    aaguid = $5,
    os_name = $6,
    browser_name = $7,
    user_agent = $8,
    created_at = $9,
    updated_at = $10,
    last_used_at = $11
WHERE id = $12;

-- name: DeletePasskeyChallenge :exec
DELETE FROM passkey_challenges
WHERE id = $1;

-- name: DeletePasskeyCredential :exec
DELETE FROM passkey_credentials
WHERE id = $1;
