data "aws_iam_policy_document" "external_secrets_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-secrets-sa"]
    }
  }
}

resource "aws_iam_role" "external_secrets_role" {
  name               = "webapp-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume.json
}

data "aws_iam_policy_document" "external_secrets_policy" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:webapp-*"
    ]
  }
}

resource "aws_iam_role_policy" "external_secrets_attachment" {
  name   = "webapp-external-secrets-policy"
  role   = aws_iam_role.external_secrets_role.id
  policy = data.aws_iam_policy_document.external_secrets_policy.json
}