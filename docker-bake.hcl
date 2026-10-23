variable "PHP_VERSIONS" {
  default = ["8.3", "8.4", "8.5"]
}

variable "LATEST_PHP_VERSION" {
  default = "8.4"
}

variable "PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
}

variable "GHCR_IMAGE" {
  default = "ghcr.io/tomas-kulhanek/docker-php"
}

variable "IMAGES" {
  default = [GHCR_IMAGE]
}

variable "REPO_URL" {
  default = "https://github.com/tomas-kulhanek/docker-php"
}

# Passed in from Makefile. Only main updates the mutable latest tags.
variable "BRANCH" {
  default = ""
}

variable "SHA" {
  default = ""
}

group "default" {
  targets = ["php"]
}

target "php" {
  name = "php-${replace(ver, ".", "-")}"
  matrix = {
    ver = PHP_VERSIONS
  }

  context    = "."
  dockerfile = "Dockerfile"
  platforms  = PLATFORMS
  args = {
    PHP_VERSION = ver
  }

  tags = concat(
    BRANCH == "main" ? flatten([for img in IMAGES : concat(
      ["${img}:${ver}-latest"],
      ver == LATEST_PHP_VERSION ? ["${img}:latest"] : []
    )]) : [],
    SHA != "" ? ["${GHCR_IMAGE}:${ver}-${SHA}"] : []
  )

  labels = {
    "org.opencontainers.image.created"     = timestamp()
    "org.opencontainers.image.description" = "PHP ${ver} FPM with nginx and supervisor"
    "org.opencontainers.image.url"         = REPO_URL
    "org.opencontainers.image.source"      = REPO_URL
    "org.opencontainers.image.revision"    = SHA
  }
}
