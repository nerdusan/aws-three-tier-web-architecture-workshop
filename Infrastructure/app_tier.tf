# Internal Load Balancer
resource "aws_lb" "internal" {
  name               = "internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.int_alb.id]
  subnets            = [aws_subnet.web_1.id, aws_subnet.web_2.id]
}

resource "aws_lb_target_group" "app" {
  name     = "app-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
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
  image_id      = "ami-007855ac798b5175e" # Ubuntu 22.04 LTS AMI for us-east-1
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_tier.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt-get install -y nodejs git

              mkdir -p /var/www/node-app
              cd /var/www/node-app

              cat << 'NODEAPP' > package.json
              {
                "name": "node-api",
                "version": "1.0.0",
                "main": "server.js",
                "dependencies": {
                  "express": "^4.18.2",
                  "mysql2": "^3.6.0"
                }
              }
              NODEAPP

              cat << 'SERVER' > server.js
              const express = require('express');
              const mysql = require('mysql2');
              const app = express();

              const db = mysql.createConnection({
                host: "${aws_rds_cluster.aurora.endpoint}", 
                user: "${aws_rds_cluster.aurora.master_username}",
                password: "SuperSecretPassword123!", 
                database: "${aws_rds_cluster.aurora.database_name}"
              });

              app.get('/health', (req, res) => {
                res.status(200).send('OK');
              });

              app.get('/api/data', (req, res) => {
                db.query('SELECT "Hello from Aurora Multi-AZ MySQL" AS message', (err, results) => {
                  if (err) return res.status(500).send(err);
                  res.json(results);
                });
              });

              app.listen(3000, () => console.log('App running on port 3000'));
              SERVER

              npm install
              sudo npm install pm2 -g
              pm2 start server.js
              pm2 save
              pm2 startup
              EOF
  )
}

# App Tier Autoscaling Group
resource "aws_autoscaling_group" "app" {
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
