# ========================================================
# MODULE RÉSEAU : VPC Multi-AZ, Sous-réseaux, Routage & NAT
# ========================================================

# 1. VPC Dédié au projet
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-vpc"
  })
}

# 2. Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-igw"
  })
}

# 3. Sous-réseaux Publics (ALB & NAT)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-subnet-1a"
    Tier = "Public"
  })
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-subnet-1b"
    Tier = "Public"
  })
}

# 4. Sous-réseaux Privés Applicatifs (Auto Scaling Group EC2)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-app-subnet-1a"
    Tier = "PrivateApp"
  })
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-app-subnet-1b"
    Tier = "PrivateApp"
  })
}

# 5. Sous-réseaux Privés Base de Données (Amazon RDS)
resource "aws_subnet" "db_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-db-subnet-1a"
    Tier = "PrivateDB"
  })
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-db-subnet-1b"
    Tier = "PrivateDB"
  })
}

# 6. Table de Routage Publique (Vers Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# 7. AMI Amazon Linux 2023 pour l'instance NAT minimale
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group pour l'Instance NAT
resource "aws_security_group" "nat" {
  name        = "${var.prefix}-nat-sg"
  description = "Autorise le routage sortant pour les instances des sous-reseaux prives"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Trafic depuis les sous-reseaux prives"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_1_cidr, var.private_subnet_2_cidr]
  }

  egress {
    description = "Trafic sortant vers Internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat-sg"
  })
}

# Instance NAT EC2 (Alternative économique au NAT Gateway managé AWS à 32$/mois)
resource "aws_instance" "nat" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  source_dest_check           = false # Obligatoire pour agir comme routeur NAT
  associate_public_ip_address = true
  iam_instance_profile        = "LabInstanceProfile"

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # Script de configuration automatique du forwarding et de masquerade iptables (compatible AL2023)
  user_data = <<-EOF
              #!/bin/bash
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipforward.conf
              dnf install -y iptables-nft
              DEV=$(ip -4 route show default | awk '{print $5}')
              iptables -t nat -A POSTROUTING -o $DEV -j MASQUERADE
              iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
              iptables -A FORWARD -i 10.0.0.0/16 -j ACCEPT
              EOF

  tags = merge(var.tags, {
    Name = "${var.prefix}-nat-instance"
    Role = "NAT"
  })
}

# 8. Table de Routage Privée (Route vers l'instance NAT)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.nat.primary_network_interface_id
  }

  tags = merge(var.tags, {
    Name = "${var.prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# 9. Table de Routage Base de Données (Complètement isolée, sans accès Internet)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.prefix}-db-isolated-rt"
  })
}

resource "aws_route_table_association" "db_1" {
  subnet_id      = aws_subnet.db_1.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_2" {
  subnet_id      = aws_subnet.db_2.id
  route_table_id = aws_route_table.db.id
}

# 10. S3 VPC Gateway Endpoint (Gratuit & direct vers S3)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.public.id,
    aws_route_table.private.id
  ]

  tags = merge(var.tags, {
    Name = "${var.prefix}-s3-gateway-endpoint"
  })
}
