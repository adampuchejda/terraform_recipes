provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


# VPC
resource "aws_vpc" "monitoring_vpc" {
  cidr_block = "10.0.0.0/16"
}


# Public subnet
resource "aws_subnet" "monitoring_subnet_public" {
  vpc_id            = aws_vpc.monitoring_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}


# Internet gateway
resource "aws_internet_gateway" "monitoring_internet_gateway" {
  vpc_id = aws_vpc.monitoring_vpc.id
}


# Route table
resource "aws_route_table" "monitoring_route_table" {
  vpc_id = aws_vpc.monitoring_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.monitoring_internet_gateway.id
  }
}


# Public subnet associated with route table
resource "aws_route_table_association" "route_association" {
  subnet_id      = aws_subnet.monitoring_subnet_public.id
  route_table_id = aws_route_table.monitoring_route_table.id
}


# Security group
resource "aws_security_group" "allow_subnet_traffic" {
  name        = "allow_basic_subnet_traffic"
  description = "HTTP, HTTPS and SSH traffic to and from subnet"
  vpc_id      = aws_vpc.monitoring_vpc.id

  ingress {
    description      = "HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Network interface with an IP in the subnet
resource "aws_network_interface" "webserver" {
  subnet_id       = aws_subnet.monitoring_subnet_public.id
  private_ips     = ["10.0.1.11"]
  security_groups = [aws_security_group.allow_subnet_traffic.id]
}

resource "aws_eip" "elastic_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.webserver.id
  associate_with_private_ip = "10.0.1.11"
}

resource "aws_instance" "ubuntu_with_apache" {
  ami           = "ami-04505e74c0741db8d"
  instance_type = "t2.micro"
  key_name      = "terraform"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.webserver.id
  }

  user_data = <<EOF
#!/bin/bash
apt update
apt upgrade -y
apt install apache2 -y
systemctl start apache2
echo "Hey, Adam! Is that you on that Ubuntu?" > /var/www/html/index.html
EOF
}
