package main

import (
	"database/sql"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/horriblename/rss-aggre/internal/database"
)

func fetchFeedLoop(cfg apiConfig) {
	ticker := time.NewTicker(gFetchFeedInterval)
	for {
		fetchFeeds(cfg)
		<-ticker.C
	}
}

func fetchFeeds(cfg apiConfig) {
	feeds, err := cfg.queries.GetNextFeedsToFetch(cfg.ctx, 10)
	if err != nil {
		log.Printf("db get next feeds to fetch: %s", err)
		return
	}

	if len(feeds) == 0 {
		log.Printf("INFO no feeds to fetch")
		return
	}

	log.Printf("INFO fetching %d feeds", len(feeds))

	var wg sync.WaitGroup
	for _, feed := range feeds {
		wg.Add(1)

		var last_fetched *time.Time
		if feed.LastFetchedAt.Valid {
			last_fetched = &feed.LastFetchedAt.Time
		}

		go func(url string, feed_id uuid.UUID, last_fetched *time.Time) {
			defer wg.Done()
			cfg.scrapeFeed(url, feed_id, last_fetched)
		}(feed.Url, feed.ID, last_fetched)
	}

	wg.Wait()
}

func (cfg *apiConfig) scrapeFeed(url string, feed_id uuid.UUID, last_fetched *time.Time) {
	log.Printf("INFO fetching from: %s", url)
	rss, err := fetchFeed(url)
	if err != nil {
		log.Printf("fetching feed from %s: %s", url, err)
		return
	}

	items := rss.Channel.Items
	if last_fetched != nil {
		end := 0
		for i, item := range items {
			if time.Time(item.PubDate).Compare(*last_fetched) <= 0 {
				end = i
				break
			}
		}
		items = items[:end]
	}

	for _, item := range items {
		cfg.writeFeedToDB(item, feed_id)
	}

	if err := cfg.queries.MarkFeedFetched(cfg.ctx, database.MarkFeedFetchedParams{
		FetchedAt: sql.NullTime{Time: time.Now(), Valid: true},
		FeedID:    feed_id,
	}); err != nil {
		log.Printf("db mark feed fetched: %s", err)
	}
}

func (cfg *apiConfig) writeFeedToDB(item Item, feed_id uuid.UUID) {
	media_id := uuid.NullUUID{}

	tx, err := cfg.db.Begin()
	if err != nil {
		log.Printf("db begin transaction: %s", err)
		return
	}
	defer tx.Rollback()

	qtx := cfg.queries.WithTx(tx)

	if item.Enclosure != nil {
		media_id.UUID = uuid.New()
		media_id.Valid = true

		if _, err := qtx.CreateMedia(cfg.ctx, database.CreateMediaParams{
			ID:       media_id.UUID,
			Url:      item.Enclosure.Url,
			Length:   int32(item.Enclosure.Length),
			Mimetype: item.Enclosure.Type,
		}); err != nil {
			log.Printf("db create media: %s", err)
			return
		}
	}

	sourceUrl := sql.NullString{}
	sourceName := sql.NullString{}
	if item.Source != nil {
		sourceUrl.String = item.Source.Url
		sourceUrl.Valid = true
		sourceName.String = item.Source.Name
		sourceName.Valid = true
	}

	if _, err := qtx.CreatePost(cfg.ctx, database.CreatePostParams{
		ID:          uuid.New(),
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
		Title:       item.Title,
		Url:         item.Link,
		Description: sql.NullString{String: item.Description, Valid: true},
		PublishedAt: time.Time(item.PubDate),
		FeedID:      feed_id,
		Guid: sql.NullString{
			String: item.Guid,
			Valid:  item.Guid != "",
		},
		MediaID:    media_id,
		SourceUrl:  sourceUrl,
		SourceName: sourceName,
	}); err != nil {
		log.Printf("db create post: %s", err)
		return
	}

	err = tx.Commit()
	if err != nil {
		log.Printf("db commiting transaction: %s", err)
		return
	}
}
