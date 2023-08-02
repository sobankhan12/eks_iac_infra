# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
terraform {
  required_providers {

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }

  }
}

locals {
  resource_name = "${var.project_name}-${var.environment_name}"
}
data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "eks_cluster_iam_policy_document" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${local.resource_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_iam_policy_document.json
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_security_group" "eks-cluster-sg" {
  name        = "${local.resource_name}-eks-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.resource_name}-cluster-sg"
    Environment = "${var.environment_name}"
  }
}

resource "aws_security_group_rule" "eks-cluster-ingress-workstation-https" {
  cidr_blocks       = [local.workstation-external-cidr]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks-cluster-sg.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "eks-cluster" {
  name                      = "${local.resource_name}-cluster"
  role_arn                  = aws_iam_role.eks_cluster_role.arn
  version                   = var.cluster_version
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    security_group_ids = [aws_security_group.eks-cluster-sg.id]
    subnet_ids         = var.subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks-cluster-AmazonEKSVPCResourceController,
  ]

}
resource "aws_eks_addon" "addons" {
  for_each          = { for addon in var.addons : addon.name => addon }
  cluster_name      = aws_eks_cluster.eks-cluster.name
  addon_name        = each.value.name
  addon_version     = each.value.version
  resolve_conflicts = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng
  ]
}

# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${local.resource_name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks-node-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_role.name
}
resource "aws_iam_role_policy_attachment" "eks-node-AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "eks_on_demand_ng" {

  count           = var.create_on_demand_ng ? 1 : 0
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${local.resource_name}-on_demaond-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids
  # added by me
  instance_types = var.on_demand_instance_types
  capacity_type  = "ON_DEMAND"
  ##
  scaling_config {
    desired_size = var.eks_on_demand_desired_size
    max_size     = var.eks_on_demand_max_size
    min_size     = var.eks_on_demand_min_size
  }
  tags = {
    Environment = var.environment_name
  }
  depends_on = [
    aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}
# added by whole resource
resource "aws_eks_node_group" "eks_spot_ng" {

  count           = var.create_spot_ng ? 1 : 0
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "${local.resource_name}-spot-ng"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = var.spot_instance_types
  capacity_type  = "SPOT"

  scaling_config {
    desired_size = var.eks_spot_desired_size
    max_size     = var.eks_spot_max_size
    min_size     = var.eks_spot_min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Workstation External IP
# This configuration is not required and is
# only provided as an example to easily fetch
# the external IP of your local workstation to
# configure inbound EC2 Security Group access
# to the Kubernetes cluster.

data "http" "workstation-external-ip" {
  url = "https://ifconfig.me/ip"
}
# data "http" "my-works" {
#   url = "https://ifconfig.me/ip"
# }

# Override with variable or hardcoded value if necessary
locals {
  workstation-external-cidr = "${chomp(data.http.workstation-external-ip.body)}/32"
}




##################   INGRESS CONTROLLER   ###############################
resource "time_sleep" "wait_for_eks" {
  create_duration = "15m"
}
data "tls_certificate" "eks-tls" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_open_id" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks-tls.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_open_id.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_open_id.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller_role" {
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role_policy.json
  name               = "${local.resource_name}-aws-lb-controller-role" #change was made to test Terraform implimentation aws-load-balancer-controller-${var.region}
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {

  policy = file("${path.module}/AWSLoadBalancerController.json")
  name   = "${local.resource_name}-aws-lb-controller-policy" # for multiregion AWSLoadBalancerController-${var.region}
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller_role.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}

resource "null_resource" "dependency" {
  depends_on = [aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

  # Noop resource block, used only for dependency
}

## helm.tf  
provider "helm" {

  kubernetes {
    host                   = aws_eks_cluster.eks-cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks-cluster.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks-cluster.id]
      command     = "aws"
      env = {
        #AWS_PROFILE = var.aws_profile_name # Replace with your AWS profile name
      }
    }
  }
}
provider "kubernetes" {
  load_config_file       = false
  host                   = aws_eks_cluster.eks-cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks-cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks-cluster.id]
    command     = "aws"
    env = {
      #AWS_PROFILE = var.aws_profile_name # Replace with your AWS profile name
    }
  }
}
provider "kubectl" {

  host                   = aws_eks_cluster.eks-cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks-cluster.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks-cluster.id]
    command     = "aws"
    env = {
     # AWS_PROFILE = var.aws_profile_name # Replace with your AWS profile name
    }
  }
}

resource "helm_release" "aws-load-balancer-controller" {

  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.4.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks-cluster.id
  }

  set {
    name  = "image.tag"
    value = "v2.4.2"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller_role.arn
  }

  #  depends_on = [
  #    aws_eks_node_group.eks_spot_ng,
  #    aws_eks_node_group.eks_on_demand_ng,

  #    aws_iam_role_policy_attachment.aws_load_balancer_controller_attach
  #  ]
  depends_on = [helm_release.karpenter, aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

}



##############   KARPENTER ADDONDS    ##########################################
data "aws_iam_policy_document" "karpenter_controller_assume_role_policy" {
  count = var.enable_cluster_karpenter ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_open_id.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_open_id.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "karpenter_controller_role" {
  count              = var.enable_cluster_karpenter ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_role_policy[count.index].json
  name               = "${local.resource_name}-karpenter-controller-role"
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  count  = var.enable_cluster_karpenter ? 1 : 0
  policy = file("${path.module}/karpenter-controller-policy.json")
  name   = "${local.resource_name}-karpenter-controller-policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  count      = var.enable_cluster_karpenter ? 1 : 0
  role       = aws_iam_role.karpenter_controller_role[count.index].name
  policy_arn = aws_iam_policy.karpenter_controller_policy[count.index].arn
}

resource "aws_iam_instance_profile" "karpenter" {
  count = var.enable_cluster_karpenter ? 1 : 0
  name  = "${local.resource_name}-KarpenterNodeInstanceProfile"
  role  = aws_iam_role.eks_node_role.name
}


############### helm for karpenter  ##########################
resource "helm_release" "karpenter" {
  count            = var.enable_cluster_karpenter ? 1 : 0
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "0.16.1"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller_role[count.index].arn
  }

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks-cluster.id
  }

  set {
    name  = "clusterEndpoint"
    value = aws_eks_cluster.eks-cluster.endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter[count.index].name
  }
  set {
    name  = "replicas"
    value = 1
  }

  #  depends_on = [aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng, ]
  depends_on = [aws_iam_role_policy_attachment.karpenter_controller_attach, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

}

resource "kubectl_manifest" "karpenter_provisioner" {
  depends_on = [time_sleep.wait_for_eks, helm_release.karpenter, aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

  count     = var.enable_cluster_karpenter ? 1 : 0
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand"]
  limits:
    resources:
      cpu: 1000
  providerRef:
    name: karpenter-provider
  ttlSecondsAfterEmpty: 30
YAML

}

resource "kubectl_manifest" "karpenter_node_template" {
  depends_on = [time_sleep.wait_for_eks, helm_release.karpenter, aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

  count     = var.enable_cluster_karpenter ? 1 : 0
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: karpenter-provider
spec:
  subnetSelector:
  
    kubernetes.io/role/internal-elb : "1"
  securityGroupSelector:
    kubernetes.io/cluster/${local.resource_name}-cluster	: owned
  YAML

}


#manifest for karpenter provider
# resource "helm_release" "karpenter_provisioner" {
#   depends_on = [helm_release.karpenter,aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

#   name       = "karpenter_provisioner"
#   repository = "https://charts.itscontained.io"
#   chart      = "raw"
#   version    = "0.2.5"
# values = [
#     <<-EOF
#     resources:
#     - apiVersion: karpenter.sh/v1alpha5
#       kind: Provisioner
#       metadata:
#         name: default
#       spec:
#         requirements:
#         - key: karpenter.sh/capacity-type
#           operator: In
#           values: ["on-demand"]
#         limits:
#           resources:
#             cpu: 1000
#         providerRef:
#           name: my-provider
#         ttlSecondsAfterEmpty: 30
#       EOF
# ]
# }

# resource "helm_release" "karpenter_node_template" {
#   depends_on = [helm_release.karpenter,aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

#   name       = "karpenter_node_template"
#   repository = "https://charts.itscontained.io"
#   chart      = "raw"
#   version    = "0.2.5"
# values = [
#     <<-EOF
#     resources:
#     - apiVersion: karpenter.k8s.aws/v1alpha1
#       kind: AWSNodeTemplate
#       metadata:
#         name: my-provider
#       spec:
#         subnetSelector:

#           kubernetes.io/role/internal-elb : "1"
#         securityGroupSelector:
#           kubernetes.io/cluster/ob-stg-cluster: owned	

#       EOF
# ]
# }



#  resource "kubernetes_manifest" "karpenter_awsnodetemplate_provider" {
#    depends_on = [helm_release.karpenter,time_sleep.wait_for_eks,aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]
# # depends_on = [time_sleep.wait_for_eks]
#    manifest = {
#      "apiVersion" = "karpenter.sh/v1alpha5"
#      "kind"       = "Provisioner"
#      "metadata" = {
#        "name" = "default"
#      }
#      "spec" = {
#        "limits" = {
#          "resources" = {
#            "cpu" = "1k"
#          }
#        }
#        "providerRef" = {
#          "name" = "my-provider"
#        }
#        "requirements" = [
#          {
#            "key"      = "karpenter.sh/capacity-type"
#            "operator" = "In"
#            "values" = [
#              "on-demand",
#            ]
#          },
#        ]
#        "ttlSecondsAfterEmpty" = 30
#      }
#    }
#  }

#  resource "kubernetes_manifest" "karpenter_awsnodetemplate_provider" {
#  depends_on = [helm_release.karpenter,time_sleep.wait_for_eks,aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]
# # depends_on = [time_sleep.wait_for_eks]
#    manifest = {
#      "apiVersion" = "karpenter.k8s.aws/v1alpha1"
#      "kind"       = "AWSNodeTemplate"
#      "metadata" = {
#        "name" = "my-provider"
#      }
#      "spec" = {
#        "securityGroupSelector" = {
#          "kubernetes.io/cluster/${local.resource_name}-cluster" = "owned"
#        }
#        "subnetSelector" = {
#          "kubernetes.io/role/internal-elb" = "1"
#        }

#      }
#    }
#  }



##### METRIC CLUSTER ###############
resource "helm_release" "metrics_server" {
  depends_on = [aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]

  #  depends_on = [
  #   #    module.eks
  #   #  ]

  #   #count       = enable_cluster_autoscaler ? 1 : 0

  name             = "metrics-server"
  namespace        = "metrics-server"
  version          = "3.10.0"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  create_namespace = true

  set {
    name  = "replicas"
    value = 1
  }

}





########## EKS Cluster Autoscaler######################
# Policy
data "aws_iam_policy_document" "eks_cluster_autoscaler_policy_document" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeImages",
      "ec2:GetInstanceTypesFromInstanceRequirements",
      "eks:DescribeNodegroup",
    ]

    resources = ["*"]
  }


}

resource "aws_iam_policy" "eks_cluster_autoscaler_policy" {

  count = var.enable_cluster_autoscaler ? 1 : 0
  #name        = "${var.project}_${var.environment_name}_cluster_autoscaler"
  name = "${local.resource_name}-eks-cluster-autoscaler-policy"



  path        = "/"
  description = "Policy for cluster autoscaler service"

  policy = data.aws_iam_policy_document.eks_cluster_autoscaler_policy_document[0].json
}


data "aws_iam_policy_document" "eks_oidc_assume_policy_document" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks_open_id.url, "https://", "")}:sub"

      values = ["sts.amazonaws.com", "system:serviceaccount:cluster-autoscaler:cluster-autoscaler-aws-cluster-autoscaler"]

    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks_open_id.arn]
      type        = "Federated"
    }
  }
}



resource "aws_iam_role" "eks_cluster_autoscaler_role" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "${local.resource_name}-eks-ClusterAutoscalerRole"





  assume_role_policy = data.aws_iam_policy_document.eks_oidc_assume_policy_document[count.index].json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_role_attachment" {
  count      = var.enable_cluster_autoscaler ? 1 : 0
  role       = aws_iam_role.eks_cluster_autoscaler_role[count.index].name
  policy_arn = aws_iam_policy.eks_cluster_autoscaler_policy[count.index].arn
}


resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  #  depends_on = [
  #    aws_iam_role_policy_attachment.eks_cluster_autoscaler_role_attachment
  #  ]
  depends_on = [aws_eks_cluster.eks-cluster, aws_eks_node_group.eks_on_demand_ng, aws_eks_node_group.eks_spot_ng]




  name             = "cluster-autoscaler"
  namespace        = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  version          = "9.29.0"
  create_namespace = true

  set {
    name  = "awsRegion"
    value = var.aws_region
  }
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eks_cluster_autoscaler_role[count.index].arn
    type  = "string"
  }
  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.eks-cluster.id
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "2m" # Adjust the delay duration as needed
  }
  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "2m"
  }
}


# #

# #
#  resource "helm_release" "metrics_server" {
#   #  depends_on = [
#  #     module.eks
# #    ]

#     count       = enable_cluster_autoscaler ? 1 : 0

#     name             = "metrics-server"
#     namespace        = "metrics-server"
#     version          = "3.10.0"
#     repository       = "https://kubernetes-sigs.github.io/metrics-server/"
#     chart            = "metrics-server"
#     create_namespace = true

#     set {
#       name  = "replicas"
#       value = 1
#     }

#   }



