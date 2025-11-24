# DEV Cluster Outputs
output "dev_cluster_id" {
  description = "DEV EKS cluster ID"
  value       = aws_eks_cluster.spztech["dev"].id
}

output "dev_cluster_endpoint" {
  description = "DEV EKS cluster endpoint"
  value       = aws_eks_cluster.spztech["dev"].endpoint
}

output "dev_cluster_name" {
  description = "DEV EKS cluster name"
  value       = aws_eks_cluster.spztech["dev"].name
}

output "dev_node_group_id" {
  description = "DEV node group ID"
  value       = aws_eks_node_group.spztech["dev"].id
}

output "dev_vpc_id" {
  description = "DEV VPC ID"
  value       = aws_vpc.spztech_vpc["dev"].id
}

output "dev_subnet_ids" {
  description = "DEV subnet IDs"
  value       = [for idx in range(2) : aws_subnet.spztech_subnet["dev-${idx}"].id]
}

# PROD Cluster Outputs
output "prod_cluster_id" {
  description = "PROD EKS cluster ID"
  value       = aws_eks_cluster.spztech["prod"].id
}

output "prod_cluster_endpoint" {
  description = "PROD EKS cluster endpoint"
  value       = aws_eks_cluster.spztech["prod"].endpoint
}

output "prod_cluster_name" {
  description = "PROD EKS cluster name"
  value       = aws_eks_cluster.spztech["prod"].name
}

output "prod_node_group_id" {
  description = "PROD node group ID"
  value       = aws_eks_node_group.spztech["prod"].id
}

output "prod_vpc_id" {
  description = "PROD VPC ID"
  value       = aws_vpc.spztech_vpc["prod"].id
}

output "prod_subnet_ids" {
  description = "PROD subnet IDs"
  value       = [for idx in range(2) : aws_subnet.spztech_subnet["prod-${idx}"].id]
}
