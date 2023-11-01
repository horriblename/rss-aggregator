-- name: CreatePost :one
INSERT INTO posts (
	id,
	created_at,
	updated_at,
	title,
	url,
	description,
	published_at,
	feed_id,
	media_id,
	source_url,
	source_name
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING *;

-- name: GetPostsByUser :many
SELECT p.*, m.url AS media_url, m.length_ AS media_length, m.mimetype AS media_type
FROM posts p
	LEFT JOIN feed_follows ff
		ON p.feed_id = ff.feed_id
	LEFT JOIN media m
		ON m.id = p.media_id
WHERE ff.user_id = $1
ORDER BY p.published_at DESC
LIMIT $2;
