# EKS Cluster Configuration

# EKS Cluster Module (using terraform-aws-modules/eks/aws from registry)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "latest"

  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.eks_version

  vpc_id             = var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id
  private_subnet_ids = var.vpc_private_subnet_ids != [] ? var.vpc_private_subnet_ids : module.vpc.private_subnet_ids
  public_subnet_ids  = var.vpc_public_subnet_ids != [] ? var.vpc_public_subnet_ids : module.vpc.public_subnet_ids

  # Cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Enable IRSA
  enable_irsa = true

  # EKS Add-ons
  enable_amazon_eks_vpc_cni             = true
  enable_amazon_eks_coredns             = true
  enable_amazon_eks_kube_proxy          = true
  enable_amazon_eks_aws_ebs_csi_driver  = true

  # AWS Load Balancer Controller
  enable_aws_load_balancer_controller = true

  # Cluster Autoscaler
  enable_cluster_autoscaler = true

  # Control plane logging
  control_plane_subnet_ids = var.vpc_public_subnet_ids

  # Security group
  create_security_group = true
  security_group_rules = {
    ingress = {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  }

  # IAM roles
  create_iam_role = true
  iam_role_name   = "${var.project_name}-eks-${var.environment}"

  # Kubernetes namespace
  create_namespace = true
  namespace_name   = var.project_name

  # Tags
  tags = var.tags

  depends_on = [module.vpc]
}

# EKS Node Group (using eks-managed-node-group sub-module)
module "eks_nodegroup" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "latest"

  cluster_name    = module.eks.cluster_name
  node_group_name = "${var.project_name}-nodes-${var.environment}"
  instance_types  = var.eks_instance_types

  # Capacity
  desired_size = var.eks_desired_capacity
  min_size     = var.eks_min_capacity
  max_size     = var.eks_max_capacity

  # Networking
  vpc_id             = var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id
  private_subnet_ids = var.vpc_private_subnet_ids != [] ? var.vpc_private_subnet_ids : module.vpc.private_subnet_ids

  # AMI
  ami_type       = "AL2_x86_64"
  aws_ami_id_based_on_ami = data.aws_ami.eks_worker.id

  # IAM
  create_iam_role = true
  iam_role_name   = "${var.project_name}-eks-nodegroup-${var.environment}"

  # Labels and taints
  labels = {
    environment = var.environment
    workload    = "evershop"
  }

  # Taints (optional)
  taints = []

  # Launch template configuration
  launch_template_name = "${var.project_name}-lt-${var.environment}"
  launch_template_use_name_prefix = true

  # Disk size
  ebs_volume_size = var.eks_node_disk_size

  # Tags
  tags = var.tags

  depends_on = [module.eks]
}

# EKS Monitoring (using fargate-profile sub-module for monitoring namespace)
module "eks_fargate_profile" {
  source  = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version = "latest"

  cluster_name = module.eks.cluster_name
  name         = "${var.project_name}-fargate-${var.environment}"

  # Pod execution role
  create_pod_execution_role = true
  pod_execution_role_name   = "${var.project_name}-fargate-pod-${var.environment}"

  # Subnets
  subnet_ids = var.vpc_private_subnet_ids

  # Selectors for namespaces
  selectors = [
    {
      namespace = "kube-system"
      labels = {
        k8s-app = "kube-dns"
      }
    },
    {
      namespace = var.project_name
      labels = {
        workload = "monitoring"
      }
    }
  ]

  # Tags
  tags = var.tags

  depends_on = [module.eks]
}