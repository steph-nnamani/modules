
# Get the default VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_vpc" "default" {
    default = true
}

# Filters subnets where the vpc-id matches the ID of the 
# default VPC from the above data source.
data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [aws_default_vpc.default.id]
    }
}

resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-instance"
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = local.tcp_protocol
        cidr_blocks = local.all_ips
    }

    # Allow all outbound requests
    egress {
        from_port   = local.any_port
        to_port     = local.any_port
        protocol    = local.any_protocol
        cidr_blocks = local.all_ips
    }
}

# The remote state backend data store for mysql database
data "terraform_remote_state" "db" {
    backend = "s3"
    config = {
        bucket = var.db_remote_state_bucket
        key = var.db_remote_state_key
        region = "us-east-1"
    }
}

resource "aws_launch_template" "example" {
    name_prefix   = var.cluster_name
    image_id = "ami-0866a3c8686eaeeba"
    instance_type = var.instance_type
    
    vpc_security_group_ids = [aws_security_group.instance.id]
    
    # Render the user data script as a template
    # adding ${path.module}/ before the file name. This tells Terraform to 
    # look for the file in the module's directory rather than the root module directory.
    user_data = base64encode(templatefile("${path.module}/user-data.sh", {
        server_port = var.server_port
        db_address  = try(data.terraform_remote_state.db.outputs.address, "db-not-available")
        db_port     = try(data.terraform_remote_state.db.outputs.port, "3306")
    }))
     
    # Required when using a launch configuration with an auto scaling group
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "example" {
    vpc_zone_identifier = data.aws_subnets.default.ids
    target_group_arns = [aws_lb_target_group.asg.arn]
    
    health_check_type = "ELB"
    min_size = var.min_size
    max_size = var.max_size

    launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
    }

    # Static tag
    # tag {
    #     key = "Name"
    #     value = "${var.cluster_name}-asg"
    #     propagate_at_launch = true
    # }

    dynamic "tag" {
        for_each = var.custom_tags

        content {
            key = tag.key
            value = tag.value
            propagate_at_launch = true 
        }
    }
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
    # You can set value to either true or false in different environments.
    count = var.enable_autoscaling ? 1 : 0  

    scheduled_action_name = "scale-out-during-business-hours"
    min_size = 2
    max_size = 10
    desired_capacity = 10
    recurrence = "0 9 * * *"
    autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
    # You can set value to either true or false in different environments.
    count = var.enable_autoscaling ? 1 : 0 

    scheduled_action_name = "scale-in-at-night"
    min_size = 2
    max_size = 10
    desired_capacity = 2
    recurrence = "0 17 * * *"
    autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_lb" "example" {
    name = "${var.cluster_name}-asg"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = local.http_port
    protocol = "HTTP"
    
    # By default, return a simple 404 page
    default_action {
        type = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "404: Page not found"
            status_code = 404
        }
    }
}

resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
    type = "ingress"
    security_group_id = aws_security_group.alb.id
    
    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
    type = "egress"
    security_group_id = aws_security_group.alb.id

    from_port = local.any_port
    to_port = local.any_port
    protocol = local.any_protocol
    cidr_blocks = local.all_ips    
}

resource "aws_lb_target_group" "asg" {
    name = "${var.cluster_name}-asg"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asg.arn
    }
}

resource "null_resource" "test_deployment" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Testing connection to ${aws_lb.example.dns_name}..."
      
      # Add a sleep to allow the ALB and instances to initialize
      echo "Waiting for 60 seconds for ALB to become ready..."
      sleep 60
      
      # Try to curl the ALB DNS name with a longer timeout
      curl -m 15 http://${aws_lb.example.dns_name}

      # Check the curl exit status
      if [ $? -eq 0 ]; then
         echo -e "\nSuccess: Server is responding"
      else
         echo -e "\nError: Server is not responding"
         exit 1
      fi  
    EOT
    interpreter = ["C:/Program Files/Git/bin/bash.exe", "-c"]
  }
  
  # Make sure to depend on both the ALB and ASG
  depends_on = [
    aws_lb.example,
    aws_autoscaling_group.example,
    aws_lb_listener.http,
    aws_lb_listener_rule.asg
  ]
}
