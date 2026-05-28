# Internal Load Balancer
resource "aws_lb" "internal" {
  name               = "app-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.int_alb.id]
  subnets            = [aws_subnet.web_1.id, aws_subnet.web_2.id]
}

resource "aws_lb_target_group" "app" {
  name_prefix     = "app-"
  port     = 4000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/healthcheck"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# App Tier Launch Template with fully integrated User Data for Node.js & DB connection
resource "aws_launch_template" "app" {
  name_prefix   = "app-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_tier.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo dnf update -y
              sudo dnf install git -y
              
              # Setup Node.js 18 environment
              curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
              sudo dnf install nodejs -y

              cd /home/ec2-user
              git clone https://github.com/nerdusan/aws-three-tier-web-architecture-workshop.git aws-three-tier-web-architecture

              # Navigate inside the app-tier folder based on the corrected repo path
              cd /home/ec2-user/aws-three-tier-web-architecture/application-code/app-tier

              # Bind live Aurora environment parameters
              export DB_HOST="${aws_rds_cluster.aurora.endpoint}"
              export DB_USER="${aws_rds_cluster.aurora.master_username}"
              export DB_PASSWORD="SuperSecretPassword123!"
              export DB_NAME="${aws_rds_cluster.aurora.database_name}"

              npm install
              sudo npm install pm2 -g
              
              # Execute background daemon mapping your configuration parameters
              DB_HOST=$DB_HOST DB_USER=$DB_USER DB_PASSWORD=$DB_PASSWORD DB_NAME=$DB_NAME pm2 start index.js --name "node-backend-api"
              
              pm2 save
              sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user
              EOF
  )
}
resource "aws_autoscaling_group" "app" {
  name                = "app-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  target_group_arns   = [aws_lb_target_group.app.arn]
  vpc_zone_identifier = [aws_subnet.app_1.id, aws_subnet.app_2.id]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
}