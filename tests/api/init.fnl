(require :http.request)
(local {: base-url} (require :tests.api.vars))
(local {: test} (require :tests.api.tester))
(local f string.format)
(local log (require :tests.api.log))

(lambda endpoint [s]
  (f "http://%s/%s" base-url s))

(lambda any [list predicate]
  (var found false)
  (each [_ v (ipairs list) &until found]
    (set found (predicate v)))
  found)

(lambda header [name value ?never_index]
  {: name : value :never_index (or ?never_index false)})

(lambda status-ok [res] (= res.status :200))

(test "GET readiness"
      :GET
      (endpoint :v1/readiness)
      {:asserts [status-ok]})

(var api-key nil)
(test "POST users: create user"
      :POST
      (endpoint :v1/users)
      {:body {:name :John}
      :asserts [status-ok #(= $1.body.name :John)]
      :scripts [#(set api-key (assert $1.body.apikey))]})

(local authed_header (header :Authorization (f "ApiKey %s" api-key)))

(test "GET users: verify authentication"
      :GET
      (endpoint :v1/users)
      {:headers [authed_header]
      :asserts [status-ok]})

(var feed_id nil)
(test "POST feeds: create feed"
      :POST
      (endpoint :v1/feeds)
      {:headers [authed_header]
      :body {:name "First Feed by John" :url "example.com"}
      :asserts [status-ok #(= $.body.url "example.com")]
      :scripts [#(set feed_id (assert $.body.id))]})

(test "GET feeds: get feeds"
      :GET
      (endpoint :v1/feeds)
      {:asserts [status-ok]})

(local x (test "Feed is auto-followed upon creation"
      :GET (endpoint :v1/feed_follows)
      {:headers [authed_header]
      :asserts [status-ok
                #(any $.body #(= $.feed_id feed_id))]}))

(var feed_follow_id nil)
(test "POST feed_follows: create feed follow"
      :POST
      (endpoint :v1/feed_follows)
      {:headers [authed_header]
      :body {:feed_id feed_id}
      :asserts [status-ok #(= $.body.feed_id feed_id)]
      :scripts [#(set feed_follow_id (assert $.body.id))]})

(test "DELETE feed_follows/{id}: delete feed follow"
      :DELETE
      (endpoint (f :v1/feed_follows/%s feed_follow_id))
      {:asserts [status-ok]})

(test "GET feed_follows: get feed follows of user"
      :GET
      (endpoint :v1/feed_follows)
      {:headers [authed_header]
      :asserts [status-ok
                 #(= (type $.body) "table")]})



