locals {
  cluster_name = var.cluster_name
}
module "vpc" {
  ############################ VPC VARIABLES ##########################
  source                     = "./modules/vpc"
  project_name               = var.project_name
  aws_region                 = "eu-west-1"
  vpc_cidr_block             = "10.0.0.0/16"
  environment_name           = var.environment_name
  cluster_name               = local.cluster_name
  public_subnet_cidr_blocks  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]


}
# module "waf" {
# ############################ WAF VARIABLES #############################
#   source                           = "./modules/waf"
#   project = "pentajunior"
#   waf_name = "Kl-WAF"
#   waf_scope = "REGIONAL"
#   web_acl_description = "AWS Managed WAf Rules"
# }

module "eks" {
  ############################ EKS VARIABLES #############################
  source                         = "./modules/eks"
  environment_name               = var.environment_name
  project_name                   = var.project_name
  cluster_version                = "1.24"
  cluster_endpoint_public_access = "true"
  aws_profile_name               = var.aws_profile_name
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.public_subnets_id
  private_subnet_ids             = module.vpc.private_subnets_id
  enabled_cluster_log_types      = ["audit"]
  # added by me

  create_on_demand_ng        = true                      #by default true   #values= yes or false
  on_demand_instance_types   = ["t3.large"]              # default t3.medium
  eks_spot_desired_size      = 1                         # default 1
  eks_spot_min_size          = 1                         # default 1
  eks_spot_max_size          = 3                         # default 1
  create_spot_ng             = false                     # by default false  # values= yes or false
  spot_instance_types        = ["t3.large", "t3.medium"] #  default t3.large
  eks_on_demand_desired_size = 1                         # default 1
  eks_on_demand_min_size     = 1                         # default 1
  eks_on_demand_max_size     = 3                         # default 1
  # two addons for cluster scaling karpenter and cluster autoscaler enable one of them
  enable_cluster_autoscaler = true
  enable_cluster_karpenter  = false


}





