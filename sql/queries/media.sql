-- name: CreateMedia :one
INSERT INTO media (id, url, length_, mimetype)
VALUES ($1, $2, $3, $4)
RETURNING *;
