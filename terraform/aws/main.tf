# AWS side of the CA: a Roles Anywhere trust anchor holding the CA
# certificate, roles that each trust exactly one subject's certificates, and
# the profile through which certificates assume them.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  # Roles Anywhere is regional: the trust anchor and profile live here, and
  # aws_signing_helper finds the region in the trust anchor's ARN
  region = var.region
  # refuses to plan or apply against any other account
  allowed_account_ids = [var.aws_account_id]
}

locals {
  # "<role name> <policy ARN>" -> the attachment
  policy_attachments = merge([
    for name, role in var.roles : {
      for arn in role.policy_arns : "${name} ${arn}" => { role = name, policy_arn = arn }
    }
  ]...)
}

# Applying a new CA certificate updates the trust anchor in place.
resource "aws_rolesanywhere_trust_anchor" "this" {
  name    = var.name
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = var.ca_certificate
    }
  }
}

data "aws_iam_policy_document" "trust" {
  for_each = var.roles

  statement {
    actions = [
      "sts:AssumeRole",
      # Roles Anywhere tags the session with the certificate's fields and sets
      # its source identity to the subject's CN
      "sts:TagSession",
      "sts:SetSourceIdentity",
    ]
    principals {
      type        = "Service"
      identifiers = ["rolesanywhere.amazonaws.com"]
    }
    # the certificate chains to this trust anchor's CA
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_rolesanywhere_trust_anchor.this.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/x509Subject/CN"
      values   = [each.value.subject]
    }
  }
}

resource "aws_iam_role" "role" {
  for_each = var.roles

  name                 = each.key
  description          = "Assumable with ${var.name}'s Roles Anywhere certificate for ${each.value.subject}"
  assume_role_policy   = data.aws_iam_policy_document.trust[each.key].json
  max_session_duration = var.session_duration
}

resource "aws_iam_role_policy_attachment" "role" {
  for_each = local.policy_attachments

  role       = aws_iam_role.role[each.value.role].name
  policy_arn = each.value.policy_arn
}

# The roles the CA's certificates may assume, and how long sessions last.
resource "aws_rolesanywhere_profile" "this" {
  name             = var.name
  enabled          = true
  role_arns        = [for role in aws_iam_role.role : role.arn]
  duration_seconds = var.session_duration
}
