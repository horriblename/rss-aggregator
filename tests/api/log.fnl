(local fnl (require :fennel))

(lambda indent [s ?indentation]
  (local ?indentation (or ?indentation "\t"))
  (table.concat 
	 (icollect [line (string.gmatch s "([^\n]+)")]
		(.. ?indentation line)) 
	 "\n"))

(lambda fail [s ...]
  (print (indent (.. "\x1b[31m[ FAIL ] \x1b[0m" (string.format s ...)))))

(lambda pass [s ...]
  (print (indent (.. "\x1b[32m[ OK ] \x1b[0m" (string.format s ...)))))

(lambda result [s ...]
  (print (indent (.. "\x1b[36m[ RESULT ] \x1b[0m" (string.format s ...)))))

(lambda response [res]
  (print "Response:")
  (print (fnl.view res))
  (print))

(lambda err [s ...]
  (print (indent (.. "\x1b[31m[ ERR ] \x1b[0m" (string.format s ...)))))

(fn view [obj]
  (print (string.format "[debug]: " (fnl.view obj))))

{: fail : pass : result : response : view : err}
