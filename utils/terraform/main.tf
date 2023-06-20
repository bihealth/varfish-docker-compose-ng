# Mangement of the GitHub project.

resource "github_repository" "varfish-docker-compose-ng" {
  name        = "varfish-docker-compose-ng"
  description = "(Next-generation; in-development) VarFish Docker Compose"

  has_issues = true
  visibility = "public"

  allow_rebase_merge     = false
  allow_merge_commit     = false
  delete_branch_on_merge = true

  has_downloads          = false
  has_projects           = false
  has_wiki               = false

  vulnerability_alerts   = true

  squash_merge_commit_message = "BLANK"
  squash_merge_commit_title   = "PR_TITLE"
}
