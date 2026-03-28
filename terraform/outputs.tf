output "public_ip" {
  value = module.compute.public_ip
}

output "private_ip" {
  value = module.compute.private_ip
}

output "mon_public_ip" {
  value = module.monitoring.mon_public_ip
}

output "app_sg_id" {
  value = module.compute.app_sg_id
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "subnet_ids" {
  value = module.networking.subnet_ids
}

output "subnet_ids_db" {
  value = module.networking.subnet_ids_db
}