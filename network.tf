locals {
  game_port = 7777
  beacon_port = 15000
  query_port = 15777
  satisfactory_ports = [local.game_port, local.beacon_port, local.query_port]
  host = "${chomp(data.http.icanhazip.response_body)}/32"
}

data "http" "icanhazip" {
  url = "http://icanhazip.com"
}

resource "aws_vpc" "satisfactory" {
  cidr_block       = "10.69.0.0/16"
  instance_tenancy = "default"
}

resource "aws_subnet" "satisfactory_public" {
  vpc_id     = aws_vpc.satisfactory.id
  cidr_block = "10.69.1.0/24"
}

resource "aws_internet_gateway" "satisfactory" {
  vpc_id = aws_vpc.satisfactory.id
}

resource "aws_route" "satisfactory" {
  route_table_id            = aws_vpc.satisfactory.default_route_table_id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.satisfactory.id
}

resource "aws_route_table_association" "satisfactory" {
  route_table_id            = aws_vpc.satisfactory.default_route_table_id
  subnet_id      = aws_subnet.satisfactory_public.id
}

resource "aws_security_group" "management" {
  name = "management"
  vpc_id = aws_vpc.satisfactory.id

  // To Allow SSH Transport
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [local.host]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [local.host]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "satisfactory" {
  name = "Satisfactory"
  vpc_id = aws_vpc.satisfactory.id

  dynamic "ingress" {
    for_each = local.satisfactory_ports
    content {
      from_port = ingress.value
      protocol = "udp"
      to_port = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  
  dynamic "ingress" {
    for_each = local.satisfactory_ports
    content {
      from_port = ingress.value
      protocol = "tcp"
      to_port = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "allow_outgoing" {
  name = "outgoing default"
  vpc_id = aws_vpc.satisfactory.id
  
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }


  lifecycle {
    create_before_destroy = true
  }
}
