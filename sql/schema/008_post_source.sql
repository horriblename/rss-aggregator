-- +goose Up
ALTER TABLE posts
	ADD COLUMN source_url VARCHAR(255),
	ADD COLUMN source_name VARCHAR(255);

-- +goose Down
ALTER TABLE posts
	DROP COLUMN source_url,
	DROP COLUMN source_name;


