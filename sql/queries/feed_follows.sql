-- name: DeleteFeedFollow :one
DELETE FROM feed_follows
	WHERE id = $1
	RETURNING *;

-- name: GetFeedsOfUser :many
SELECT * FROM feed_follows
WHERE user_id = $1;
