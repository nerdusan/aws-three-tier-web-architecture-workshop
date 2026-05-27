output "public_alb_dns" {
  description = "The public facing URL of your React web app"
  value       = aws_lb.external.dns_name
}

output "internal_alb_dns" {
  description = "The internal endpoint used inside Nginx configurations"
  value       = aws_lb.internal.dns_name
}

output "database_endpoint" {
  description = "The writer endpoint for your Node.js application to connect to"
  value       = aws_rds_cluster.aurora.endpoint
}
