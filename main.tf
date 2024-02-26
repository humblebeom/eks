# ----------------------------------------
# 이 작업은 다음 사항을 전제로 한다
# 1. aws configure 인증이 되어 있을 것(admin권한)
# 2. 적합한 이름의 vpc 및 서브넷들이 생성되어 있을 것
# 3. NAT Gateway를 생성할 것
# 4. 라우팅 테이블을 통해 ngw와 vpc가 연결되어 있을 것
# ----------------------------------------

#  1. EKS Cluster IAM Role

resource "aws_iam_role" "eks_cluster_iam_role" {
  name = "nby-eks-cluster-iam-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# 2. IAM Role policy 

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_iam_role.name
}

# 3. EKS Cluster
# my_eks_cluster는 테라폼 파일 내에서 참조가 되는 이름
# my-eks-cluster는 실제로 AWS에서 생성되는 리소스 이름

resource "aws_eks_cluster" "my_eks_cluster" {
  name     = "nby-eks-cluster"
  role_arn =  aws_iam_role.eks_cluster_iam_role.arn 
  version = "1.29"
  vpc_config {
    security_group_ids = [data.aws_security_group.my_sg_web.id]         
    subnet_ids         = concat(data.aws_subnet.my_pvt_2a[*].id, data.aws_subnet.my_pvt_2c[*].id) # 두 개 이상 배열 결합, [*]는 해당 데이터 소스로부터 반환된 모든 요소를 나열하도록 Terraform에 지시합니다.
    endpoint_private_access = true # 동일 vpc 내 private ip간 통신허용
    endpoint_public_access = true
   }
  }

# 4. Node Group IAM Role

resource "aws_iam_role" "eks_node_iam_role" {
  name = "nby-eks-node-iam-role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# iam role policy

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_iam_role.name
}

# 5. EKS Node Group

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.my_eks_cluster.name
  node_group_name = "worker-node-group"
  node_role_arn   = aws_iam_role.eks_node_iam_role.arn
  subnet_ids      = concat(data.aws_subnet.my_pvt_2a[*].id, data.aws_subnet.my_pvt_2c[*].id)
  instance_types = ["t2.micro"]
  capacity_type  = "ON_DEMAND"  # 요금제. 최근에는 spot instance를 많이 사용하는 추세
  remote_access {
#    source_security_group_ids = [data.aws_security_group.my_sg_web.id]
    ec2_ssh_key               = "nby-key"
  }
  labels = {
    "role" = "eks_node_iam_role"
  }
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
    }
  tags =  {
    Name = "nby-worker"
  }
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
