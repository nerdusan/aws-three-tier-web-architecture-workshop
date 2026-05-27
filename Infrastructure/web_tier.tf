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
  image_id      = "ami-007855ac798b5175e" # Ubuntu 22.04 LTS AMI for us-east-1 (Change if using different region)
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web_tier.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install nginx -y

              # Configure Nginx as a reverse proxy for /api routing to Internal ALB
              sudo cat << 'NNGINX' > /etc/nginx/sites-available/default
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;

                  root /var/www/html;
                  index index.html;

                  server_name _;

                  location / {
                      try_files $uri $uri/ /index.html;
                  }

                  location /api/ {
                      proxy_pass http://${aws_lb.internal.dns_name};
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade $http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host $host;
                      proxy_cache_bypass $http_upgrade;
                  }
              }
              NNGINX

              # Dummy React build file placeholder
              echo "<h1>React App (Served via Nginx)</h1><p>API requests routed to internal tier.</p>" | sudo tee /var/www/html/index.html

              sudo systemctl restart nginx
              sudo systemctl enable nginx
              EOF
  )
}

# Web Tier Autoscaling Group
resource "aws_autoscaling_group" "web" {
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
