# AWS Three-Tier Web Architecture (Automated via Terraform)

This repository contains the complete infrastructure-as-code (Terraform) and application source code to deploy a highly available, secure, and fault-tolerant three-tier web application on AWS.

The architecture separates responsibilities into distinct layers: a public-facing web tier (React compiled via Nginx), a private application tier (Node.js API managed by PM2), and a private database tier (Amazon Aurora MySQL).
./Repository Directory Structure

aws-three-tier-web-architecture/         # REPOSITORY ROOT
tree --invalid-path

 Infrastructure/                      # Terraform Configuration Files
     main.tf                         # Provider configuration & dynamic AMI queries
     vpc.tf                          # Subnets, Gateways, Route Tables, and NAT
     web_tier.tf                      # Public ALB, Web Launch Template & Web ASG
     app_tier.tf                      # Internal ALB, App Launch Template & App ASG
     iam.tf                          # EC2 SSM instance profile permissions
     security_groups.tf               # ISolated tier-to-tier firewall rules
     outputs.tf                      # Exposed infrastructure outputs
 application-code/                    # Monorepo Application Source Code
     nginx.conf                       # Custom reverse-proxy & React configuration
     db_setup.sql                     # Database schema seed file
     web-tier/                        # Frontend React Application (Raw Source)
     app-tier/                        # Backend Node.js API Service

---

## Architecture Flow
1. Web Tier: Scaled across multiple Availability Zones using an Auto Scaling Group (ASG) inside private subnets. Traffic is routed via an Internet-Facing Application Load Balancer. Nginx hosts a dynamically built React production build and reverse-proxies API calls down to the internal load balancer.
2. Application Tier: Scaled across separate private subnets using an ASG. Listens natively on port 4000. Nodes are managed as background daemons using PM2. Traffic arrives via a completely internal Application Load Balancer.
3. Database Tier: An Amazon Aurora MySQL Serverless/Cluster architecture deployed securely across isolated database subnets, accepting data operations strictly from the application tier security group.

---

## Deployment Instructions

### Prerequisites
* Terraform installed locally (v1.5+ recommended).
* AWS CLI configured with proper deployment credentials.
* Your default AWS profile or environment target configured for your region (e.g., us-east-1).

### Step 1: Provision Infrastructure
Navigate to your Infrastructure/ directory wher your Terraform files live:

    cd Infrastructure

Initialize the workspace to download providers and setup module states:

    terraform init

Review the structural additions that will be appended to your AWS account:

    terraform plan

Execute the deployment blueprint (type yes when prompted to confirm):

terraform apply

Note: The script dynamically looks up the latest Amazon Linux 2023 base AMI, builds your network topologies, spins up the database cluster, and establishes your Auto Scaling Groups.


## Step 2: Allow Application Bootstrapping
When the EC2 instances initialize, they automatically carry out background tasks defined in their user_data templates:

Web Tier: Automatically installs Node.js, clones this repository, runs npm install, compiles the raw React code via npm run build, structures local file access permissions, replaces the Nginx configurations with your internal load balancer's live DNS mapping, and activates the web routing loops.

App Tier: Automatically pulls Node.js, setups dependencies, sets target environment flags matching your live Aurora endpoints, and mounts the runtime loop into the system systemd configuration under PM2 control.


Please wait 5 to 7 minutes after terraform apply finishes for automated compilation steps to wrap up across all live targets.


## Step 3: Seed the Database Schema
Because the Node.js backend requires its database schema to be initialized to respond successfully to Load Balancer health check queries (/healthcheck), you must run the database seed file.

Go to the AWS Console and navigate to EC2 -> Instances.
Select one of your running private app-template instances and click Connect.
Choose the Session Manager tab and click Connect (No SSH keys required).
Run the seed script against your dynamic Aurora cluster endpoint (outputted by your Terraform apply stage):

cd /home/ec2-user/aws-three-tier-web-architecture/application-code/

mysql -h YOUR_AURORA_CLUSTER_ENDPOINT -u admin -p appdb < db_setup.sql

    Enter your database master password when prompted (Default placeholder configuration setup: SuperSecretPassword123!).

Force PM2 to refresh its background environment state to discover the new data definitions:

    sudo -u ec2-user pm2 restart node-backend-api


# Verification & Monitoring
## Health Checks
Navigate to EC2 -> Target Groups inside the AWS console to verify cluster convergence:

web-tg targets should report Healthy on port 80 (monitoring /health).
app-tg targets should report Healthy on port 4000 (monitoring /healthcheck).


## Accessing the Web Application
Retrieve the public DNS string from the External Load Balancer via the console or your terraform outputs file, copy it into any modern web browser, and navigate directly to your live frontend user interface:
http://external-alb-xxxxxxxxx.us-east-1.elb.amazonaws.com

## Clean-Up Instructions
To tear down your deployment and ensure you do not incur ongoing charges for active AWS components, execute the removal macro from the Infrastructure/ directory:

terraform destroy