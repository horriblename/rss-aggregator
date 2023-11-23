-- +goose Up
CREATE TABLE revokedTokens (
  token TEXT UNIQUE NOT NULL PRIMARY KEY,
  expiresAt TIMESTAMP NOT NULL
);

-- +goose Down
DROP TABLE revokedTokens;
