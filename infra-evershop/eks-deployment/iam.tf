# IAM Configuration for EKS Cluster
# Task 3.4.1: Create iam.tf file

# =============================================================================
# EKS Node IAM Role
# =============================================================================

resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-eks-node-role-${var.environment}"
  })
}

# AmazonEKSWorkerNodePolicy
resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# AmazonEKS_CNI_Policy
resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# AmazonEC2ContainerRegistryPowerUser
resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# =============================================================================
# Custom IAM Policies
# =============================================================================

# CloudWatch Logs Policy
resource "aws_iam_policy" "cloudwatch_logs" {
  name = "${var.project_name}-cloudwatch-logs-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/eks/${var.project_name}/*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_cloudwatch_logs" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Secrets Manager Policy
resource "aws_iam_policy" "secrets_manager" {
  name = "${var.project_name}-secrets-manager-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project_name}/*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_secrets_manager" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.secrets_manager.arn
}

# X-Ray Write Policy
resource "aws_iam_policy" "xray_write" {
  name = "${var.project_name}-xray-write-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_xray" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.xray_write.arn
}

# =============================================================================
# OIDC Provider for IRSA
# =============================================================================

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-oidc-${var.environment}"
  })
}

# =============================================================================
# IRSA Service Account Roles
# =============================================================================

# GraphQL API Service Account Role
resource "aws_iam_role" "graphql_api" {
  name = "${var.project_name}-graphql-api-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:evershop:graphql-api"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-graphql-api-role-${var.environment}"
  })
}

resource "aws_iam_role_policy_attachment" "graphql_api_rds" {
  role       = aws_iam_role.graphql_api.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy_attachment" "graphql_api_secrets" {
  role       = aws_iam_role.graphql_api.name
  policy_arn = aws_iam_policy.secrets_manager.arn
}

resource "aws_iam_role_policy_attachment" "graphql_api_logs" {
  role       = aws_iam_role.graphql_api.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Frontend Service Account Role
resource "aws_iam_role" "frontend" {
  name = "${var.project_name}-frontend-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:evershop:frontend"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-frontend-role-${var.environment}"
  })
}

resource "aws_iam_role_policy_attachment" "frontend_s3" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Monitoring Service Account Role
resource "aws_iam_role" "monitoring" {
  name = "${var.project_name}-monitoring-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:monitoring:monitoring"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-monitoring-role-${var.environment}"
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_cloudwatch" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

# =============================================================================
# Cluster Autoscaler IAM Role
# =============================================================================

resource "aws_iam_role" "cluster_autoscaler" {
  name = "${var.project_name}-cluster-autoscaler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-cluster-autoscaler-role-${var.environment}"
  })
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${var.project_name}-cluster-autoscaler-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "autoscaling:DescribeInstanceRefresh"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled" = "true"
            "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_policy" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# =============================================================================
# AWS Load Balancer Controller IAM Role
# =============================================================================

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-lbc-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-aws-lbc-role-${var.environment}"
  })
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-lbc-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/ingress.k8s.aws/cluster" = module.eks.cluster_name
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_policy" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# =============================================================================
# EBS CSI Driver IAM Role
# =============================================================================

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-ebs-csi-driver-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${module.eks.cluster_oidc_issuer_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${module.eks.cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
    Name        = "${var.project_name}-ebs-csi-driver-role-${var.environment}"
  })
}

resource "aws_iam_policy" "ebs_csi_driver" {
  name = "${var.project_name}-ebs-csi-driver-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeModifications",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "iam"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = aws_iam_policy.ebs_csi_driver.arn
}