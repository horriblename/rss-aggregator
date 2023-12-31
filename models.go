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
	ID       uuid.UUID `json:"id"`
	Name     string    `json:"name"`
	Url      string    `json:"url"`
	FollowID string    `json:"follow_id,omitempty"`
}

func FeedWithFollowsFromDB(feeds *database.GetFeedsWithFollowsRow) FeedWithFollows {
	followID := ""
	if feeds.FollowID.Valid {
		followID = feeds.FollowID.UUID.String()
	}
	return FeedWithFollows{
		ID:       feeds.ID,
		Name:     feeds.Name,
		Url:      feeds.Url,
		FollowID: followID,
	}
}

type User struct {
	ID        uuid.UUID `json:"id"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Name      string    `json:"name"`
	Apikey    string    `json:"apikey"`
}

func UserFromDB(user *database.User) User {
	return User{
		ID:        user.ID,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
		Name:      user.Name,
		Apikey:    user.Apikey,
	}
}

type LoginResponse struct {
	UserID       uuid.UUID `json:"id"`
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
}
