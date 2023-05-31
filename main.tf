resource "aws_security_group" "sg" {
  name        = "${var.name}-${var.env}-sg"
  description = "${var.name}-${var.env}-sg" #"Allow TLS inbound traffic"
  vpc_id      = var.vpc_id #aws_vpc.main.id

  ingress {
    description      = "APP" # "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = var.allow_app_cidr #[aws_vpc.main.cidr_block]
  }

  ingress {
    description      = "SSH" # "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.bastion_cidr #[aws_vpc.main.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-${var.env}-sg" })
}

resource "aws_launch_template" "template" {
 # name              = "${var.name}-${var.env}-tmplt"
  name_prefix   = "${var.name}-${var.env}"
  image_id      = data.aws_ami.ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }
  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    name = var.name
    env  = var.env
  }))
}

resource "aws_autoscaling_group" "asg" {
  name              = "${var.name}-${var.env}-asg"
#   availability_zones = ["us-east-1a"]
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]
  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = local.asg_tags
    content {
        key                 = tag.key
        propagate_at_launch = true #tag.value.propagate_at_launch
        value               = tag.value
    }
  }
}

resource "aws_lb_target_group" "main" {
  name     = "${var.name}-${var.env}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  tags     = merge(var.tags, { Name = "${var.name}-${var.env}-tg" })
}

resource "aws_lb_listener_rule" "rule" {
  listener_arn = var.listener_arn
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.dns_name]
    }
  }
}

resource "aws_route53_record" "main" {
  zone_id = var.domain_id4040
  name    = local.dns_name
  type    = "CNAME"
  ttl     = 45
  records = [var.lb_dns_name]
}


# resource "aws_instance" "roboshop" {
#     ami           = data.aws_ami.ami.id # ami = "ami-0b5a2b5b8f2be4ec2"
#     instance_type = var.instance_type
#     subnet_id     = var.subnet_id
# }

