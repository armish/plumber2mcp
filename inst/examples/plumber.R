#* Echo back the input
#* @param msg The message to echo
#* @get /echo
function(msg = "") {
  list(message = paste("Echo:", msg))
}

#* Add two numbers
#* @param a First number
#* @param b Second number
#* @post /add
function(a, b) {
  list(result = as.numeric(a) + as.numeric(b))
}

#* Get current time
#* @get /time
function() {
  list(time = Sys.time())
}

#* Parse JSON data
#* @param data JSON string to parse
#* @post /parse
function(req) {
  data <- req$body
  list(
    parsed = data,
    type = class(data)
  )
}