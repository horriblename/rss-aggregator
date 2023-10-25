package main

import (
	"encoding/xml"
	"net/http"
)

type RSS struct {
	Channel Channel `xml:"channel"`
}

type Channel struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	Description string `xml:"description"`
	Items       []Item `xml:"item"`
}

type Item struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	Description string `xml:"description"`
}

func fetchFeed(url string) (RSS, error) {
	res, err := http.Get(url)
	if err != nil {
		return RSS{}, err
	}

	var rss RSS
	if err := xml.NewDecoder(res.Body).Decode(&rss); err != nil {
		return RSS{}, err
	}

	return rss, nil
}
