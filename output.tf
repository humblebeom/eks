
#==============================================================================================================================
# 1. eks_cluster_iam_role
# 2. eks_node_iam_role
# 3. brokurly_eks_cluster
# 4. eks_node_group
#==============================================================================================================================
output eks_cluster_iam_role {
    value = aws_iam_role.eks_cluster_iam_role
}
output eks_node_iam_role {
    value = aws_iam_role.eks_node_iam_role
}
output brokurly_eks_cluster {
    value = aws_eks_cluster.my_eks_cluster
}
output eks_node_group {
    value = aws_eks_node_group.eks_node_group
}
