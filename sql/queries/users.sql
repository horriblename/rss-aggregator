-- name: CreateUser :one
INSERT INTO users (id, created_at, updated_at, name, passwordHash)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetUser :one
SELECT *
FROM users
WHERE apikey = $1
LIMIT 1;

-- name: GetUserFromName :one
SELECT *
FROM users
WHERE name = $1
LIMIT 1;

-- name: GetUserFromID :one
SELECT *
FROM users
WHERE id = $1
LIMIT 1;

-- name: DeleteUser :exec
DELETE FROM users
WHERE id = $1;
