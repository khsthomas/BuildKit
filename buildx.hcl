group "default" {
	targets = ["php73", "nginx-base"]
}

target "cache" {
  cache-to = ["type=inline"]
}

target "php73" {
	inherits = ["cache"]
}

target "nginx-base" {
	inherits = ["cache"]
}

