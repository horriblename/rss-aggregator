package main

import (
	"encoding/xml"
	"reflect"
	"testing"
	"time"
)

const testcase = `
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Boot.dev Blog</title>
    <link>https://blog.boot.dev/</link>
    <description>Recent content on Boot.dev Blog</description>
    <generator>Hugo -- gohugo.io</generator>
    <language>en-us</language>
    <lastBuildDate>Sun, 22 Oct 2023 00:00:00 +0000</lastBuildDate><atom:link href="https://blog.boot.dev/index.xml" rel="self" type="application/rss+xml" />
    <item>
      <title>Title 1</title>
      <link>https://blog.boot.dev/blog1</link>
      <pubDate>Sun, 22 Oct 2023 00:00:00 +0000</pubDate>
      
      <guid>https://blog.boot.dev/python/queue-data-structure-python/</guid>
      <description>Description One</description>
		<enclosure url="http://www.scripting.com/mp3s/file.mp3" length="12216320" type="audio/mpeg" />
		<source url="https://blog.boot.dev/">Boot.dev Blog</source>
    </item>
    
    <item>
      <title>Title 2</title>
      <link>https://blog.boot.dev/blog2</link>
      <pubDate>Fri, 06 Oct 2023 00:00:00 +0000</pubDate>
      
      <guid>https://blog.boot.dev/golang/can-go-used-web-development/</guid>
      <description>Description Two</description>
    </item>
  </channel>
</rss>
`

func TestParseRSS(t *testing.T) {
	var rss RSS
	err := xml.Unmarshal([]byte(testcase), &rss)
	if err != nil {
		t.Errorf("unmarshal xml: %s", err)
	}

	date1, err := time.Parse(time.RFC1123, "Sun, 22 Oct 2023 00:00:00 +0000")
	if err != nil {
		t.Errorf("parsing date1: %s", err)
	}
	date2, err := time.Parse(time.RFC1123, "Fri, 06 Oct 2023 00:00:00 +0000")
	if err != nil {
		t.Errorf("parsing date2: %s", err)
	}

	expect := RSS{
		Channel: Channel{
			Title: "Boot.dev Blog",
			// Link: "https://blog.boot.dev",
			Description: "Recent content on Boot.dev Blog",
			Items: []Item{
				{
					Title:       "Title 1",
					Link:        "https://blog.boot.dev/blog1",
					PubDate:     PubDate(date1),
					Description: "Description One",
					Guid:        "https://blog.boot.dev/python/queue-data-structure-python/",
					Enclosure: &Enclosure{
						Url:    "http://www.scripting.com/mp3s/file.mp3",
						Length: 12216320,
						Type:   "audio/mpeg",
					},
					Source: &Source{
						Url:  "https://blog.boot.dev/",
						Name: "Boot.dev Blog",
					},
				},
				{
					Title:       "Title 2",
					Link:        "https://blog.boot.dev/blog2",
					PubDate:     PubDate(date2),
					Description: "Description Two",
					Guid:        "https://blog.boot.dev/golang/can-go-used-web-development/",
				},
			},
		},
	}

	if !reflect.DeepEqual(expect, rss) {
		t.Errorf("not equal")
	}
}
