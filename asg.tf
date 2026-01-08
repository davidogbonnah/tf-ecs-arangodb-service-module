resource "aws_launch_template" "arangodb_ecs_workers" {
  name_prefix   = "arangodb-ecs-worker-"
  image_id      = data.aws_ami.arangodb_ecs_ami.id
  instance_type = "t3.medium"
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    DATA_DEVICE="/dev/xvdb"
    MOUNT_POINT="/var/lib/arangodb"

    if [ -b "$DATA_DEVICE" ]; then
      if ! blkid "$DATA_DEVICE" >/dev/null 2>&1; then
        mkfs -t ext4 "$DATA_DEVICE"
      fi
      mkdir -p "$MOUNT_POINT"
      if ! mountpoint -q "$MOUNT_POINT"; then
        mount "$DATA_DEVICE" "$MOUNT_POINT"
      fi
      if ! grep -q "$DATA_DEVICE" /etc/fstab; then
        echo "$DATA_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
      fi
    fi
    echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
    EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.arangodb_ecs_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdb"
    ebs {
      volume_size = var.arangodb_data_volume_size
      volume_type = var.arangodb_data_volume_type
    }
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }
}

resource "aws_autoscaling_group" "arangodb_ecs_workers_asg" {
  name                = "arangodb-ecs-workers"
  desired_capacity    = 3
  min_size            = 3
  max_size            = 4
  vpc_zone_identifier = var.private_subnet_ids

  protect_from_scale_in = true
  
  launch_template {
    id      = aws_launch_template.arangodb_ecs_workers.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "arangodb-ecs-worker"
    propagate_at_launch = true
  }

  force_delete = true
}

resource "aws_ecs_capacity_provider" "arangodb_ecs_workers" {
  name = "arangodb-ecs-workers-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.arangodb_ecs_workers_asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "DISABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 2
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "cloud_management_cluster" {
  cluster_name       = var.cluster_name
  capacity_providers = [aws_ecs_capacity_provider.arangodb_ecs_workers.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.arangodb_ecs_workers.name
    base              = 0
    weight            = 1
  }
}

resource "aws_iam_role" "arangodb_ecs_instance_role" {
  name = "arangodb-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "arangodb_ecs_instance_role_policy" {
  role       = aws_iam_role.arangodb_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "arangodb_ecs_instance_profile" {
  name = "arangodb-ecs-instance-profile"
  role = aws_iam_role.arangodb_ecs_instance_role.name
}