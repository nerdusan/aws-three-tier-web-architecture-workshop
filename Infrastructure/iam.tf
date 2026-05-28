# Infrastructure/iam.tf

# 1. Create the IAM Role for EC2
resource "aws_iam_role" "ec2_ssm" {
  name = "three-tier-ec2-ssm-role"

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
}

# 2. Attach the Core SSM Policy to the Role
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Create the Instance Profile that your Launch Templates are looking for
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "three-tier-ec2-instance-profile"
  role = aws_iam_role.ec2_ssm.name
}