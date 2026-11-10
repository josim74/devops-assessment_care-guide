# IAM Role assumed by the EC2 instance (No static access keys)
resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-care-guide-ec2-role"

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

  tags = {
    Name = "${var.environment}-care-guide-ec2-role"
  }
}

# 1. Attach AmazonSSMManagedInstanceCore for secure management without SSH keys
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 2. Attach ReadOnly ECR access for container pulling (if Amazon ECR is used)
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 3. Least-privilege inline policy for CloudWatch Logs writes, scoped strictly to the app Log Group ARN
resource "aws_iam_role_policy" "cloudwatch_write" {
  name = "${var.environment}-cloudwatch-logs-write"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.app_logs.arn}:*"
        ]
      }
    ]
  })
}

# IAM Instance Profile to attach the role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-care-guide-instance-profile"
  role = aws_iam_role.ec2_role.name
}
