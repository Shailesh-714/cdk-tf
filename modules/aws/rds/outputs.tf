output "rds_cluster_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "RDS cluster writer endpoint"
}

output "rds_cluster_reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "RDS cluster reader endpoint"
}
