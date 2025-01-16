resource "aws_instance" "satisfactory_server" {
    ami = var.ami_id
    associate_public_ip_address = true
    user_data = filebase64("${var.nixos_config}")
    user_data_replace_on_change = true
    vpc_security_group_ids = [
        aws_security_group.satisfactory.id,
        aws_security_group.management.id,
        aws_security_group.allow_outgoing.id
    ]
    root_block_device {
      volume_size = 40
      volume_type = "gp3"
      delete_on_termination = true
    }
    subnet_id = aws_subnet.satisfactory_public.id
    instance_type = var.instance_type
    key_name = var.ami_key_pair_name
    iam_instance_profile = aws_iam_instance_profile.satisfactory.name
}

resource "aws_eip" "satisfactory_eip" {
  domain = "vpc"
}

resource "aws_eip_association" "satisfactory" {
  instance_id   = aws_instance.satisfactory_server.id
  allocation_id = aws_eip.satisfactory_eip.id
}

output "instance_ip_addr" {
  value = aws_eip_association.satisfactory.public_ip
}
