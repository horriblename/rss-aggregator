package main

import (
	"encoding/xml"
	"errors"
	"net/http"
	"time"
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
	Title       string  `xml:"title"`
	Link        string  `xml:"link"`
	PubDate     PubDate `xml:"pubDate"`
	Description string  `xml:"description"`
}

type PubDate time.Time

var (
	ErrParsePubDate = errors.New("could not parse a pubDate subelement")
)

func (pd *PubDate) UnmarshalXML(d *xml.Decoder, start xml.StartElement) error {
	var s string
	if err := d.DecodeElement(&s, &start); err != nil {
		return err
	}

	// https://www.rssboard.org/rss-specification#ltpubdategtSubelementOfLtitemgt
	// example sub-element: <pubDate>Sun, 19 May 2002 15:21:36 GMT</pubDate>

	t, err := time.Parse(time.RFC1123, s)
	if err != nil {
		return err
	}

	*pd = PubDate(t)
	return nil
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
