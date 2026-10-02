output "target_group_arn" {
  description = "ARN do target group (consumido pelo listener e pelo service ECS)"
  value       = aws_lb_target_group.this.arn
}

output "target_group_name" {
  description = "Nome do target group"
  value       = aws_lb_target_group.this.name
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.this.arn_suffix
}
