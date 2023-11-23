-- +goose Up
ALTER TABLE posts
	 ADD CONSTRAINT posts_unique_guid UNIQUE(guid);

-- +goose Down
ALTER TABLE posts
	 DROP CONSTRAINT posts_unique_guid;
