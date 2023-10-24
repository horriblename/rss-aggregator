(local req (require :http.request))
(local json (require :cjson))
(local f string.format)
(local log (require :tests.api.log))

(lambda check-assertions [response assertions]
  "assertions is a list of fun(response): bool"
  "returns number of tests passed"
  (var fails 0)
  (each [i ass (ipairs assertions)]
	 (when (not (ass response))
		(set fails (+ fails 1))
		(log.fail (f "check #%d failed" i))))
  (- (length assertions) fails))

(lambda json_decode [msg]
  (case (pcall json.decode msg)
		  (true val) val
		  (false err) (error (f "decoding json: %s\ninput: %s" err msg))))

(lambda test [desc method url ?args]
  "request and response bodies are en/decoded to/from JSON,"
  "args may contain fields: headers, body, asserts and scripts"
  (print (.. "\n\x1b[1m" (string.rep "=" 40)))
  (print desc)
  (print (.. (string.rep "=" 40) "\x1b[0m"))
  (var ok true)
  (let [{: headers : body : asserts : scripts} (or ?args {})
			  body (or body "")
			  stream-timeout 1000]
	 (let [r (doto (req.new_from_uri url)
				  (: :set_body (json.encode body)))]
		(when headers
		  (each [_ {: name : value : never_index} (ipairs headers)]
			 (r.headers:append name value never_index)))
		(r.headers:upsert ::method method false)
		(r.headers:upsert :Content-Type "application/json")

		(let [(res_headers stream) (r:go)
				res_body (-> (stream:get_body_as_string)
								 (json_decode))
				res {:status (res_headers:get ::status)
					 :body res_body
					 :headers res_headers}]

		  (log.response res)

		  (when asserts
			 (let [passes (check-assertions res asserts)]
				(if (= passes (length asserts))
					 (log.pass "Passed %d/%d tests" passes (length asserts))
					 (log.result "Passed %d/%d tests" passes (length asserts))
					 )))

		  (when scripts
			 (each [i script (ipairs scripts)]
				(script res)))

		  res))))


{: test}
