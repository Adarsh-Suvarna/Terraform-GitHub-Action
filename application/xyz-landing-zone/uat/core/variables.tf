variable "list_of_cloud_buckets" {
  description = ""
  type = list(object({
    project_id         = string
    bucket_name        = string
    location           = string
    labels             = map(string)
    log_bucket         = string
    bucket_policy_only = bool
    encryption = object({
      key_name      = string
      key_ring_name = string
      key_location  = string
    })
    force_destroy = bool
    lifecycle_rules = list(object({
      action    = any
      condition = any
    }))
  }))
  default = []
}