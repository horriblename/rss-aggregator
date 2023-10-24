-- +goose Up
ALTER TABLE feed_follows
ADD created_at TIMESTAMP NOT NULL DEFAULT NOW(),
ADD updated_at TIMESTAMP NOT NULL DEFAULT NOW();

-- +goose Down
ALTER TABLE feed_follows
DROP created_at, updated_at;
