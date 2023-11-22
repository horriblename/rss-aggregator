-- +goose Up
ALTER TABLE users
    -- bcrypt hashes are 59/60 bytes = 472/480 bits long, depending on hashing algo and format
    ADD COLUMN passwordHash bytea NOT NULL,
    ADD CONSTRAINT user_name_unique UNIQUE(name);

-- +goose Down
ALTER TABLE users
    DROP COLUMN passwordHash,
    DROP CONSTRAINT user_name_unique;
