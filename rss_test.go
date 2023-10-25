package main

import (
	"encoding/xml"
	"log"
	"reflect"
	"testing"
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

	assert_eq(rss.Channel.Description, "Recent content on Boot.dev Blog")
	// assert_eq(rss.Channel.Link, "https://blog.boot.dev/")
	expect := RSS{
		Channel: Channel{
			Title: "Boot.dev Blog",
			// Link: "https://blog.boot.dev",
			Description: "Recent content on Boot.dev Blog",
			Items: []Item{
				{
					Title:       "Title 1",
					Link:        "https://blog.boot.dev/blog1",
					Description: "Description One",
				},
				{
					Title:       "Title 2",
					Link:        "https://blog.boot.dev/blog2",
					Description: "Description Two",
				},
			},
		},
	}

	if !reflect.DeepEqual(expect, rss) {
		t.Errorf("not equal")
	}
}

func assert_eq[T comparable](a T, b T) {
	if a != b {
		log.Fatalf("left = %v, right = %v", a, b)
	}
}
