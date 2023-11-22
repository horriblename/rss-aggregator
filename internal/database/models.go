// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.23.0

package database

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

type Feed struct {
	ID            uuid.UUID    `json:"id"`
	CreatedAt     time.Time    `json:"created_at"`
	UpdatedAt     time.Time    `json:"updated_at"`
	Name          string       `json:"name"`
	Url           string       `json:"url"`
	UserID        uuid.UUID    `json:"user_id"`
	LastFetchedAt sql.NullTime `json:"last_fetched_at"`
}

type FeedFollow struct {
	ID        uuid.UUID `json:"id"`
	UserID    uuid.UUID `json:"user_id"`
	FeedID    uuid.UUID `json:"feed_id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type Medium struct {
	ID       uuid.UUID `json:"id"`
	Url      string    `json:"url"`
	Length   int32     `json:"length_"`
	Mimetype string    `json:"mimetype"`
}

type Post struct {
	ID          uuid.UUID      `json:"id"`
	CreatedAt   time.Time      `json:"created_at"`
	UpdatedAt   time.Time      `json:"updated_at"`
	Title       string         `json:"title"`
	Url         string         `json:"url"`
	Description sql.NullString `json:"description"`
	PublishedAt time.Time      `json:"published_at"`
	FeedID      uuid.UUID      `json:"feed_id"`
	Guid        sql.NullString `json:"guid"`
	MediaID     uuid.NullUUID  `json:"media_id"`
	SourceUrl   sql.NullString `json:"source_url"`
	SourceName  sql.NullString `json:"source_name"`
}

type User struct {
	ID           uuid.UUID `json:"id"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
	Name         string    `json:"name"`
	Apikey       string    `json:"apikey"`
	Passwordhash []byte    `json:"passwordhash"`
}
