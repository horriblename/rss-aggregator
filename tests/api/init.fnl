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

(local defers [])
(lambda defer [f] (table.insert defers f))
(lambda run-defers []
  (each [_ f (ipairs defers)]
    (f)))

(fn test-api []
  (test "GET readiness"
        :GET
        (endpoint :v1/readiness)
        {:asserts [status-ok]})

  (local dummy-user {:name :John :password :abdcxyz01c})

  (var api-key nil)
  (test "POST users: create user"
        :POST
        (endpoint :v1/users)
        {:body dummy-user
        :asserts [status-ok #(= $1.body.name dummy-user.name)]
        :scripts [#(set api-key (assert $1.body.apikey))]})

  (print "pre defer")
  (defer #(test "Cleanup user"
                :DELETE
                (endpoint :v1/users)
                {:body dummy-user
                :asserts [status-ok]}))
  (print "post defer")

  (local authed_header (header :Authorization (f "ApiKey %s" api-key)))

  (test "GET users: verify authentication"
        :GET
        (endpoint :v1/users)
        {:headers [authed_header]
        :asserts [status-ok]})

  (var access-token nil)
  (var refresh-token nil)
  (test "Login"
        :POST
        (endpoint :v1/login)
        {:body dummy-user
        :asserts [status-ok]
        :scripts [#(set access-token (assert $1.body.access_token))
                  #(set refresh-token (assert $1.body.refresh_token)) ]})

  (var feed_id nil)
  (test "POST feeds: create feed"
        :POST
        (endpoint :v1/feeds)
        {:headers [authed_header]
        :body {:name "First Feed by John" :url "https://blog.boot.dev/index.xml"}
        :asserts [status-ok #(= $.body.url "https://blog.boot.dev/index.xml")]
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
                   #(= (type $.body) "table")]}))

(let [(ok err) (pcall test-api)]
  (run-defers)
  (when (not ok)
    (print "Something went wrong")
    (print err)))
