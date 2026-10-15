output "trust_anchor_arn" {
  description = "The trust anchor: --trust-anchor-arn for rolesanywhere-credentials"
  value       = aws_rolesanywhere_trust_anchor.this.arn
}

output "profile_arn" {
  description = "The profile: --profile-arn for rolesanywhere-credentials"
  value       = aws_rolesanywhere_profile.this.arn
}

output "role_arns" {
  description = "ARN of each role, by name: --role-arn for rolesanywhere-credentials"
  value       = { for name, role in aws_iam_role.role : name => role.arn }
}
