-- +goose Up
CREATE TABLE feed_follows (
	id UUID NOT NULL PRIMARY KEY,
	user_id UUID NOT NULL,
	feed_id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
	FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY(feed_id) REFERENCES feeds(id) ON DELETE CASCADE
);


-- +goose Down
DROP TABLE feed_follows;
