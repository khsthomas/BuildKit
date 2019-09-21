group "default" {
	targets = ["php73-xdebug", "nodeapp", "pythonapp", "pythonapp-nginx"]
}

target "cache" {
  cache-to = ["type=inline"]
}

target "php73-xdebug" {
	inherits = ["cache"]
}

target "nodeapp" {
	inherits = ["cache"]
}

target "pythonapp" {
	inherits = ["cache"]
}

target "pythonapp-nginx" {
	inherits = ["cache"]
}
