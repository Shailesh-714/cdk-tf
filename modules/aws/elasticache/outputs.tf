output "elasticache_cluster_endpoint_address" {
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  description = "ElastiCache Redis cluster endpoint"

}
