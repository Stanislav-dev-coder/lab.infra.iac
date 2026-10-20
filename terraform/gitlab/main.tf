terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "19.5.0"
    }
  }
}

locals {
  inventory = yamldecode(file("${path.module}/../../inventory.yml"))
  vars      = local.inventory.all.vars
  token     = regex("GITLAB_ADMIN_TOKEN=(.+)", file("${path.module}/../../.env"))[0]
}

provider "gitlab" {
  base_url = "https://gitlab.${local.vars.domain}/api/v4/"
  token    = local.token
}

