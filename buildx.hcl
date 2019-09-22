group "default" {
	targets = ["php73", "nginx-base"]
}

target "cache" {
  cache-to = ["type=inline,mode=max"]
}

target "php73" {
	inherits = ["cache"],
	// tags = [
	// 	"docker.pkg.github.com/fernandomiguel/buildkit/php:release-${LLB}-${GITHUB_SHA}-${INVOCATION_ID}",
	// 	"fernandomiguel/php:/php:release-${LLB}-${GITHUB_SHA}-${INVOCATION_ID}"
	// ]
}

target "nginx-base" {
	inherits = ["cache"]
}
