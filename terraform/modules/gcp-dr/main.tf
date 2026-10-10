
# Google Cloud Storage disaster recovery configuration
# Intended as a secondary backup location for AWS data.

resource "google_storage_bucket" "disaster_recovery" {
  name     = var.bucket_name
  project  = var.project_id
  location = var.location

  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }

    action {
      type = "Delete"
    }
  }

  labels = {
    project     = "dce04"
    purpose     = "disaster-recovery"
    environment = "assessment"
  }
}
