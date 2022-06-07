# ================== VARIABLES ==============
variable "subnet_prefix" {
  description = "cidr block subnet ip"
}
variable "ec2_instance_private_ip" {
  description = "ec2 instance private IP"
  type = string
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}


# vpc
resource "aws_vpc" "tf-test-vpc" {
  cidr_block = "172.16.0.0/16"
  tags = {
    "Name" = "tf-test-vpc"
  }
}

#internet gateway
resource "aws_internet_gateway" "tf-gw" {
  vpc_id = aws_vpc.tf-test-vpc.id
  tags = {
    Name = "tf-test-GW"
  }
}

#subnet
resource "aws_subnet" "tf-subnet-1" {
  cidr_block = var.subnet_prefix
  vpc_id = aws_vpc.tf-test-vpc.id
  availability_zone = "us-east-1a"
  tags = {
    "Name" = "dev-subnet-1"
  }
}

#route table
resource "aws_route_table" "tf-routetable" {
  vpc_id = aws_vpc.tf-test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.tf-gw.id
  }

  tags = {
    Name = "tf-iptable"
  }
}


# subnet to route tbale association
resource "aws_route_table_association" "tf-routetable-subnet-assoc" {
  subnet_id = aws_subnet.tf-subnet-1.id
  route_table_id = aws_route_table.tf-routetable.id
}

# security group
resource "aws_security_group" "tf-allow-web-traffic" {
  name        = "allow_web_traffic"
  description = "Allow traffic to & from the server"
  vpc_id      = aws_vpc.tf-test-vpc.id

  ingress {
    description      = "TLS HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "TLS HTTP traffic"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
    ingress {
    description      = "TLS SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Network interface
resource "aws_network_interface" "tf-network-interface" {
  subnet_id       = aws_subnet.tf-subnet-1.id
  private_ips     = [var.ec2_instance_private_ip]
  security_groups = [aws_security_group.tf-allow-web-traffic.id] 
}

# elastic static ip
resource "aws_eip" "tf-eip" {
  vpc      = true
  network_interface = aws_network_interface.tf-network-interface.id
  associate_with_private_ip = var.ec2_instance_private_ip
  depends_on = [aws_internet_gateway.tf-gw]
}

#Elastic computer instance 
resource "aws_instance" "tf_instance_test" {
 ami = "ami-09d56f8956ab235b3"
 instance_type = "t2.micro"
 availability_zone = "us-east-1a"
 key_name = "andrew.mititi.personal"
 network_interface {
   device_index = 0
   network_interface_id = aws_network_interface.tf-network-interface.id
 }
 user_data = <<-EOF
            #!/bin/bash
             sudo apt update -y
             sudo apt install apache2 -y
             sudo systemctl start apache2
             sudo bash -c "echo I installed my first web server using terraform > /var/www/html/index.html"
               EOF

 tags = {
   "Name" = "tf-ubuntu-test"
 }
}

output "ec2_instance_ip"  {
  value = aws_instance.tf_instance_test.public_ip
}