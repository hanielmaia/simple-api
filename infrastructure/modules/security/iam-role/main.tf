resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy_json
  tags               = var.tags
}

# Policy inline customizada (opcional) com o escopo mínimo da role
resource "aws_iam_policy" "this" {
  count       = var.attach_policy ? 1 : 0
  name        = "${var.role_name}-policy"
  description = "Policy para ${var.role_name}"
  policy      = var.policy_json
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = var.attach_policy ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

# Managed policies da AWS (ex: AmazonECSTaskExecutionRolePolicy)
resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
