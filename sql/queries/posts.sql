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
	guid,
    media_id,
    source_url,
    source_name
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
RETURNING *;

-- name: GetPostsByUser :many
SELECT
    p.id,
    p.title,
    p.url,
    p.description,
    p.published_at,
    p.feed_id,
	p.guid,
    m.url AS media_url,
    m.length_ AS media_length,
    m.mimetype AS media_type,
    COALESCE(p.source_url, f.url) AS source_url,
	COALESCE(p.source_name, f.name) AS source_name
FROM posts AS p
LEFT JOIN feed_follows AS ff
    ON p.feed_id = ff.feed_id
LEFT JOIN media AS m
    ON p.media_id = m.id
LEFT JOIN feeds AS f
    ON p.feed_id = f.id
WHERE ff.user_id = $1
ORDER BY p.published_at DESC
LIMIT $2
OFFSET $3;
