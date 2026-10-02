# Alarmes e Budget só são criados se houver e-mail para notificar
locals {
  enabled = var.alert_email != ""
}

resource "aws_sns_topic" "this" {
  count = local.enabled ? 1 : 0
  name  = "${var.name}-alerts"
  tags  = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = local.enabled ? 1 : 0
  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  count               = local.enabled ? 1 : 0
  alarm_name          = "${var.name}-ecs-cpu-high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.cluster_name, ServiceName = var.service_name }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  count               = local.enabled ? 1 : 0
  alarm_name          = "${var.name}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  count               = local.enabled ? 1 : 0
  alarm_name          = "${var.name}-rds-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_identifier }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 2147483648 # 2 GiB
  comparison_operator = "LessThanThreshold"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

# Só existe com ALB
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = local.enabled && var.alb_arn_suffix != null ? 1 : 0
  alarm_name          = "${var.name}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  count               = local.enabled && var.alb_arn_suffix != null ? 1 : 0
  alarm_name          = "${var.name}-alb-unhealthy-hosts"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = var.alb_arn_suffix, TargetGroup = var.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

# Só existe com API Gateway
resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  count               = local.enabled && var.api_id != null ? 1 : 0
  alarm_name          = "${var.name}-apigw-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = var.api_id }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.this[0].arn]
  tags                = var.tags
}

# Budget da conta (crie em um único ambiente)
resource "aws_budgets_budget" "this" {
  count        = local.enabled && var.budget_limit_usd > 0 ? 1 : 0
  name         = "${var.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
