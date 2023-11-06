package main

import (
	"time"

	"github.com/google/uuid"
	"github.com/horriblename/rss-aggre/internal/database"
)

type Post struct {
	ID          uuid.UUID  `json:"id"`
	Title       string     `json:"title"`
	Url         string     `json:"url"`
	Description string     `json:"description,omitempty"`
	PublishedAt time.Time  `json:"published_at"`
	FeedID      uuid.UUID  `json:"feed_id"`
	Guid        string     `json:"guid,omitempty"`
	Media       *Enclosure `json:"media,omitempty"` // used for attaching media
	Source      Source     `json:"source"`
}

func PostFromDB(post *database.GetPostsByUserRow) Post {
	var media *Enclosure
	if post.MediaUrl.Valid {
		media = &Enclosure{
			Url:    post.MediaUrl.String,
			Length: int(post.MediaLength.Int32),
			Type:   post.MediaType.String,
		}
	}

	return Post{
		ID:          post.ID,
		Title:       post.Title,
		Url:         post.Url,
		Description: post.Description.String,
		PublishedAt: post.PublishedAt,
		FeedID:      post.FeedID,
		Guid:        post.Guid.String,
		Media:       media,
		Source:      Source{Url: post.SourceUrl, Name: post.SourceName},
	}
}

type FeedWithFollows struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Url       string    `json:"url"`
	Following bool      `json:"following,omitempty"`
}

func FeedWithFollowsFromDB(feeds *database.GetFeedsWithFollowsRow) FeedWithFollows {
	return FeedWithFollows{
		ID:        feeds.ID,
		Name:      feeds.Name,
		Url:       feeds.Url,
		Following: feeds.Following.Valid && feeds.Following.Bool,
	}
}
