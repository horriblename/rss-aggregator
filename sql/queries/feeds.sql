-- name: CreateFeed :one
INSERT INTO feeds (id, created_at, updated_at, name, url, user_id)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetFeeds :many
SELECT * FROM feeds;

-- name: GetFeedsWithFollows :many
SELECT f.*, (NOT ff.id IS NULL) as following
FROM feeds f
LEFT JOIN feed_follows ff
	ON f.id = ff.feed_id AND ff.user_id = $1;


-- name: GetNextFeedsToFetch :many
SELECT * FROM feeds
ORDER BY last_fetched_at ASC NULLS FIRST
LIMIT $1;

-- name: MarkFeedFetched :exec
UPDATE feeds
SET last_fetched_at = sqlc.arg(fetched_at)
WHERE feeds.id = sqlc.arg(feed_id);
