module "networking" {
  source     = "./modules/networking"
  vpc_cidr   = var.vpc_cidr
  pub1_cidr  = var.pub1_cidr
  pub2_cidr  = var.pub2_cidr
  priv1_cidr = var.priv1_cidr
  priv2_cidr = var.priv2_cidr
  az1        = var.az1
  az2        = var.az2
}

module "compute" {
  source    = "./modules/compute"
  my_ip     = var.my_ip
  vpc_id    = module.networking.vpc_id
  subnet_id = module.networking.subnet_ids[0]
  # ami_id = var.ami_id
  instance_type = var.instance_type

  depends_on = [module.networking]
}

module "database" {
  source        = "./modules/database"
  subnet_ids_db = module.networking.subnet_ids_db
  vpc_id        = module.networking.vpc_id
  app_sg        = module.compute.app_sg_id
  db_user       = var.db_user
  db_password   = var.db_password

  depends_on = [module.compute, module.networking]
}

module "monitoring" {
  source        = "./modules/monitoring"
  my_ip         = var.my_ip
  vpc_id        = module.networking.vpc_id
  instance_type = var.instance_type
  subnet_id     = module.networking.subnet_ids[1]

  depends_on = [module.networking]
}