-- +goose Up
CREATE TABLE posts (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	title VARCHAR(127) NOT NULL,
	url VARCHAR(127)  NOT NULL,
	description VARCHAR(511),
	published_at TIMESTAMP NOT NULL,
	feed_id UUID NOT NULL,
	FOREIGN KEY(feed_id) REFERENCES feeds(id) ON DELETE CASCADE
);

-- +goose Down
DROP TABLE posts;
