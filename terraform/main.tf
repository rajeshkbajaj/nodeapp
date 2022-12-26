# Creating vpc , public and private subnets in us-east-1 region.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = "${var.name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  #A Internet Gateway or NAT Gateway are not created by default.
  #Setting the arguments "create_igw" and "enable_nat_gateway" to "true" will create an internet gateway and nat gateway respectively.

  enable_nat_gateway = true
  single_nat_gateway = true
  create_igw         = true

  public_subnet_tags = {
    Type = "public-subnets"
  }
  private_subnet_tags = {
    Type = "private-subnets"
  }

  tags = {
    Terraform   = "true"
    Environment = "rajesh-project"
  }
  vpc_tags = {
    Name = "${var.name}-vpc"
  }
}

# Getting the Self IP address from below define url

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}


# IAM Role for ECR

resource "aws_iam_role" "role" {
  name               = "${var.name}-ecr-role"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": ["ec2.amazonaws.com"]
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF

  tags = {
    Terraform = "true"
  }
}

resource "aws_iam_policy" "policy" {
  name = "${var.name}-ecr-access-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "attach" {
  name       = "${var.name}-attach"
  roles      = ["${aws_iam_role.role.name}"]
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.role.name
}


# Security group - Bastion Host SSH


resource "aws_security_group" "Bastion_host-self-ip" {
  name        = "Bastion_host-self-ip"
  description = "Allow self ip to ssh and allow all egress."
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from self ip"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "Bastion_host_SG"
    Terraform = "true"
  }
}

# Security group - Private instances SG


resource "aws_security_group" "allow-all-ingress-vpc" {
  name        = "allow-all-ingress-vpc"
  description = "Allow all incoming traffic from within VPC and all egress"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "all ingress from vpc"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "Private_Instance_SG"
    Terraform = "true"
  }
}


# Security group - Public web security group


resource "aws_security_group" "allow-ingress-http" {
  name        = "allow-ingress-http"
  description = "Allow incoming to port 80 from self IP and all egress"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from self ip"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "Public_Web_SG"
    Terraform = "true"
  }
}


# EC2 instance - Bastion Host


resource "aws_instance" "bastion-ec2" {
  ami             = var.ami
  instance_type   = var.instance_type
  key_name        = var.key_name
  subnet_id       = module.vpc.public_subnets[0]
  security_groups = ["${aws_security_group.Bastion_host-self-ip.id}"]

  tags = {
    Name      = "${var.name}-Bastion"
    Terraform = "true"
  }
}


# EC2 instance - jenkins


resource "aws_instance" "jenkins-ec2" {
  ami                  = var.ami
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.profile.name

  subnet_id       = module.vpc.private_subnets[0]
  security_groups = ["${aws_security_group.allow-ingress-http.id}", "${aws_security_group.allow-all-ingress-vpc.id}"]


  tags = {
    Name      = "${var.name}-Jenkins"
    Terraform = "true"
  }
}


# EC2 instance - app


resource "aws_instance" "app-ec2" {
  ami                  = var.ami
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.profile.name

  subnet_id       = module.vpc.private_subnets[1]
  security_groups = ["${aws_security_group.allow-ingress-http.id}", "${aws_security_group.allow-all-ingress-vpc.id}"]

  tags = {
    Name      = "${var.name}-AppServer"
    Terraform = "true"
  }
}