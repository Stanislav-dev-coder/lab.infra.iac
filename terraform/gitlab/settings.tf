resource "gitlab_application_settings" "this" {
  auto_devops_enabled = false
  signup_enabled      = false
}

resource "gitlab_project" "app" {
  name             = "app"
  visibility_level = "private"
}

resource "gitlab_project_deploy_token" "app" {
  project  = gitlab_project.app.id
  name     = "app"
  username = "app"
  scopes   = ["read_registry"]
}

resource "gitlab_user_runner" "runner" {
  runner_type = "instance_type"
  description = "runner"
  untagged    = true
}

resource "gitlab_user_sshkey" "root" {
  title = "lab-gitlab"
  key   = file(pathexpand("~/.ssh/lab-gitlab.pub"))
}

output "runner_token" {
  value     = gitlab_user_runner.runner.token
  sensitive = true
}

output "deploy_username" {
  value = gitlab_project_deploy_token.app.username
}

output "deploy_token" {
  value     = gitlab_project_deploy_token.app.token
  sensitive = true
}
