variable "aws_account_id" {
  description = "The AWS account this configuration manages"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  description = "Region of the trust anchor and the profile"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the trust anchor and the profile, such as the machine's hostname"
  type        = string
}

variable "ca_certificate" {
  description = "The machine's CA certificate (PEM): services.rolesanywhere.caCertificate"
  type        = string

  validation {
    condition     = can(regex("^-----BEGIN CERTIFICATE-----", var.ca_certificate))
    error_message = "ca_certificate must be a PEM certificate."
  }
}

variable "roles" {
  description = <<-EOT
    Roles the CA's certificates can assume, keyed by role name. A role's
    subject is the certificate's exact CN, "<hostname>:<user>".
  EOT
  type = map(object({
    subject     = string
    policy_arns = optional(set(string), [])
  }))
}

variable "session_duration" {
  description = "Seconds the credentials from a certificate last"
  type        = number
  default     = 3600

  validation {
    condition     = var.session_duration >= 900 && var.session_duration <= 43200
    error_message = "session_duration must be between 900 and 43200 seconds."
  }
}
