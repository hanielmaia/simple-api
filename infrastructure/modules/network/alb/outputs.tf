output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name público do ALB"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID do ALB (para registros Route53 alias)"
  value       = aws_lb.this.zone_id
}

output "alb_arn_suffix" {
  description = "Sufixo do ARN (dimensão das métricas CloudWatch)"
  value       = aws_lb.this.arn_suffix
}
