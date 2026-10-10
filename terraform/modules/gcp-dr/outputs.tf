
output "bucket_name" {
  description = "Disaster recovery bucket name."
  value       = google_storage_bucket.disaster_recovery.name
}

output "bucket_url" {
  description = "Cloud Storage bucket URL."
  value       = google_storage_bucket.disaster_recovery.url
}
