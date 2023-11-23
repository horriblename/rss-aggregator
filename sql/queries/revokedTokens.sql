-- name: RevokeToken :exec
INSERT INTO revokedTokens (token, expiresAt)
VALUES ( $1, $2 );

-- returns 1 if token was revoked, 0 if it is valid
-- name: TokenIsRevoked :one
SELECT COUNT(1)
FROM revokedTokens rt
WHERE rt.token = $1;
