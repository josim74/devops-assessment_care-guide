output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 deployment target"
  value       = aws_instance.app_server.public_ip
}

output "application_url" {
  description = "Direct HTTP URL to access the deployed web service"
  value       = "http://${aws_instance.app_server.public_ip}:${var.app_port}"
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name storing container logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "ssm_session_command" {
  description = "AWS CLI command to start a secure shell session without SSH"
  value       = "aws ssm start-session --target ${aws_instance.app_server.id} --region ${var.aws_region}"
}
