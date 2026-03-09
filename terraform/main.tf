module "networking" {
  source = "./modules/networking"
  vpc_cidr = var.vpc_cidr
  pub1_cidr = var.pub1_cidr
  pub2_cidr = var.pub2_cidr
  priv1_cidr = var.priv1_cidr
  priv2_cidr = var.priv2_cidr
  az1 = var.az1
  az2 = var.az2
}