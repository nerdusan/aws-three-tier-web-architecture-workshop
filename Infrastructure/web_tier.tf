# External Load Balancer
resource "aws_lb" "external" {
  name               = "external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ext_alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "external" {
  load_balancer_arn = aws_lb.external.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Web Tier Launch Template with integrated User Data for Nginx/React Proxy
resource "aws_launch_template" "web" {
  name_prefix   = "web-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web_tier.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # 1. Update system and install basic utilities
              sudo dnf update -y
              sudo dnf install nginx git -y

              # 2. Install Node.js & npm (Required to compile the React application)
              curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
              sudo dnf install nodejs -y

              # 3. Clone your repository root
              cd /home/ec2-user
              git clone https://github.com/nerdusan/aws-three-tier-web-architecture-workshop.git aws-three-tier-web-architecture
              
              REPO_DIR="/home/ec2-user/aws-three-tier-web-architecture"
              APP_CODE_DIR="$REPO_DIR/application-code"

              # 4. Navigate to the web-tier and dynamically compile the build folder
              cd $APP_CODE_DIR/web-tier
              npm install
              npm run build  # This automatically generates the missing 'build/' folder!

              # 5. Map the freshly compiled build to where your nginx.conf expects it
              mkdir -p /home/ec2-user/web-tier
              cp -r $APP_CODE_DIR/web-tier/build /home/ec2-user/web-tier/

              # 6. Dynamic Replace: Swap out the token in nginx.conf with the real Internal ALB DNS
              sed -i "s|\[REPLACE-WITH-INTERNAL-LB-DNS\]|${aws_lb.internal.dns_name}|g" $APP_CODE_DIR/nginx.conf

              # 7. Overwrite system configuration with your newly updated nginx.conf
              sudo cp $APP_CODE_DIR/nginx.conf /etc/nginx/nginx.conf

              # 8. Repair file permissions for Amazon Linux Nginx worker compatibility
              sudo chmod 755 /home/ec2-user
              sudo chmod -R 755 /home/ec2-user/web-tier

              # 9. Start Nginx ONLY after the build is 100% finished
              sudo systemctl daemon-reload
              sudo systemctl enable nginx
              sudo systemctl restart nginx
              EOF
  )
}
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  desired_capacity    = 2
  max_size            = 4
  min_size            = 2
  target_group_arns   = [aws_lb_target_group.web.arn]
  vpc_zone_identifier = [aws_subnet.web_1.id, aws_subnet.web_2.id]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}