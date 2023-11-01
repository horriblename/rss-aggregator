-- +goose Up
CREATE TABLE media (
    id UUID NOT NULL PRIMARY KEY,
    url TEXT NOT NULL,
    length_ INTEGER NOT NULL,
    mimetype TEXT NOT NULL
);

ALTER TABLE posts
ADD COLUMN guid TEXT,
ADD COLUMN media_id UUID,
ADD FOREIGN KEY (media_id) REFERENCES media (id) ON DELETE SET NULL;

-- +goose Down
ALTER TABLE posts
DROP COLUMN guid,
DROP COLUMN media_id;

DROP TABLE media;
