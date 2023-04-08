list_of_cloud_buckets = [
  {
    project_id         = "learn-gcp-devops-adarsh"
    bucket_name        = "learn-gcpdevops-987654"
    location           = "asia-south1"
    log_bucket         = "log-bucket"
    bucket_policy_only = true
    labels = {
      "env" : "uat"
      "app" : "gcs"
    }
    encryption = {
      "key_name" : "test",
      "key_ring_name" : "sample-keyring"
      "key_location" : "asia-south1"
    }
    force_destroy = true
    lifecycle_rules = [{
      condition = {
        age = 3
      }
      action = {
        type = "Delete"
      }
    }]
  }
]
