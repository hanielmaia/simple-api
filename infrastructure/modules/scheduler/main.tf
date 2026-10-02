# FinOps: zera as tasks fora do horário comercial (ambientes não produtivos) via EventBridge Scheduler
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scale" {
  statement {
    actions   = ["ecs:UpdateService"]
    resources = [var.ecs_service_arn]
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-scheduler"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.scale.json
}

resource "aws_scheduler_schedule" "down" {
  name                         = "${var.name}-scale-down"
  schedule_expression          = var.scale_down_cron
  schedule_expression_timezone = var.timezone
  flexible_time_window { mode = "OFF" }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.this.arn
    input = jsonencode({
      Cluster      = var.cluster_name
      Service      = var.service_name
      DesiredCount = 0
    })
  }
}

resource "aws_scheduler_schedule" "up" {
  name                         = "${var.name}-scale-up"
  schedule_expression          = var.scale_up_cron
  schedule_expression_timezone = var.timezone
  flexible_time_window { mode = "OFF" }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ecs:updateService"
    role_arn = aws_iam_role.this.arn
    input = jsonencode({
      Cluster      = var.cluster_name
      Service      = var.service_name
      DesiredCount = var.desired_count
    })
  }
}
