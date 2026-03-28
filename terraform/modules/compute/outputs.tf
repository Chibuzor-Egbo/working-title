output "public_ip" {
  value = aws_eip.app_ip.public_ip
}

output "private_ip" {
  value = aws_eip.app_ip.private_ip
}

output "app_sg_id" {
  value = aws_security_group.app_sg.id
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}