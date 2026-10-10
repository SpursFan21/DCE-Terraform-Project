
# Existing Microsoft Entra ID SAML provider.
# Imported into Terraform rather than recreated.
resource "aws_iam_saml_provider" "entra" {
  name                   = "DCE04-EntraID"
  saml_metadata_document = file("${path.root}/entra-federation.xml")
}

# SAML trust relationship for federated AWS access.
data "aws_iam_policy_document" "entra_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithSAML"]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_saml_provider.entra.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "SAML:aud"
      values   = ["https://signin.aws.amazon.com/saml"]
    }
  }
}

resource "aws_iam_role" "devops_engineer" {
  name               = "DCE04-DevOpsEngineer"
  assume_role_policy = data.aws_iam_policy_document.entra_trust.json
}

resource "aws_iam_role" "readonly_auditor" {
  name               = "DCE04-ReadOnlyAuditor"
  assume_role_policy = data.aws_iam_policy_document.entra_trust.json
}

# Match the policies currently assigned to each role.
resource "aws_iam_role_policy_attachment" "devops" {
  role       = aws_iam_role.devops_engineer.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "auditor" {
  role       = aws_iam_role.readonly_auditor.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
