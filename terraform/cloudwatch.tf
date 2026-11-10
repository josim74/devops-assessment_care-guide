# CloudWatch Log Group with explicit configurable retention period
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.environment}-care-guide-service"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.environment}-care-guide-logs"
  }
}
