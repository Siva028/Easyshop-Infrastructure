output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "API server endpoint — used in kubeconfig"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority" {
  description = "Base64-encoded CA cert — used in kubeconfig"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

# OIDC outputs — needed to create IRSA roles for pods
output "oidc_provider_arn" {
  description = "OIDC provider ARN — used in IAM role trust policies for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_role_arn" {
  description = "ARN of worker node IAM role — for creating IRSA roles that nodes can assume"
  value       = aws_iam_role.node_role.arn
}

output "node_security_group_id" {
  description = "Security group ID of worker nodes — for adding extra ingress rules"
  value       = aws_security_group.nodes.id
}

output "cluster_security_group_id" {
  description = "Security group ID of cluster control plane"
  value       = aws_security_group.cluster.id
}

output "system_node_group_name" {
  description = "System node group name"
  value       = aws_eks_node_group.system.node_group_name
}

output "app_node_group_name" {
  description = "App node group name"
  value       = aws_eks_node_group.app.node_group_name
}

output "configure_kubectl" {
  description = "Command to update local kubeconfig"
  value       = "aws eks --region ${var.tags["region"]} update-kubeconfig --name ${var.cluster_name}"
}
output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}