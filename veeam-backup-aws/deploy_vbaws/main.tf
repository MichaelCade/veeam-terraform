terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.28"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

locals {
  veeam_aws_instance_ami      = var.veeam_aws_edition == "byol" ? local.veeam_aws_instance_ami_byol : (var.veeam_aws_edition == "free" ? local.veeam_aws_instance_ami_free : local.veeam_aws_instance_ami_paid)
  veeam_aws_instance_ami_free = lookup(var.veeam_aws_free_edition_ami_map, var.aws_region)
  veeam_aws_instance_ami_byol = lookup(var.veeam_aws_byol_edition_ami_map, var.aws_region)
  veeam_aws_instance_ami_paid = lookup(var.veeam_aws_paid_edition_ami_map, var.aws_region)
}

### IAM Resources

data "aws_iam_policy_document" "veeam_aws_instance_role_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "veeam_aws_instance_role_inline_policy" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "veeam_aws_instance_role" {
  name               = "veeam-aws-instance-role"
  assume_role_policy = data.aws_iam_policy_document.veeam_aws_instance_role_assume_policy.json

  inline_policy {
    name   = "veeam-aws-instance-policy"
    policy = data.aws_iam_policy_document.veeam_aws_instance_role_inline_policy.json
  }
}

resource "aws_iam_instance_profile" "veeam_aws_instance_profile" {
  name = "veeam-aws-instance-profile"
  role = aws_iam_role.veeam_aws_instance_role.name
}

data "aws_iam_policy_document" "veeam_aws_default_role_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.veeam_aws_instance_role.arn]
    }
  }
}

resource "aws_iam_role" "veeam_aws_default_role" {
  name               = "veeam-aws-default-role"
  assume_role_policy = data.aws_iam_policy_document.veeam_aws_default_role_assume_policy.json
}

resource "aws_iam_policy" "veeam_aws_service_policy" {
  name        = "veeam-aws-service-policy"
  description = "Veeam Backup for AWS permissions to launch worker instances to perform backup and restore operations."

  policy = file("veeam-aws-service-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_service_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_service_policy.arn
}

resource "aws_iam_policy" "veeam_aws_repository_policy" {
  name        = "veeam-aws-repository-policy"
  description = "Veeam Backup for AWS permissions to create backup repositories in an Amazon S3 bucket and to access the repository when performing backup and restore operations."

  policy = file("veeam-aws-repository-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_repository_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_repository_policy.arn
}

## Backup policies

resource "aws_iam_policy" "veeam_aws_ec2_backup_policy" {
  name        = "veeam-aws-ec2-backup-policy"
  description = "Veeam Backup for AWS permissions to execute policies for EC2 data protection."

  policy = file("veeam-aws-ec2-backup-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_ec2_backup_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_ec2_backup_policy.arn
}

resource "aws_iam_policy" "veeam_aws_rds_backup_policy" {
  name        = "veeam-aws-rds-backup-policy"
  description = "Veeam Backup for AWS permissions to execute policies for RDS data protection."

  policy = file("veeam-aws-rds-backup-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_rds_backup_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_rds_backup_policy.arn
}

resource "aws_iam_policy" "veeam_aws_efs_backup_policy" {
  name        = "veeam-aws-efs-backup-policy"
  description = "Veeam Backup for AWS permissions to execute policies for EFS data protection."

  policy = file("veeam-aws-efs-backup-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_efs_backup_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_efs_backup_policy.arn
}

resource "aws_iam_policy" "veeam_aws_vpc_backup_policy" {
  name        = "veeam-aws-vpc-backup-policy"
  description = "Veeam Backup for AWS permissions to execute policies for VPC configuration backup."

  policy = file("veeam-aws-vpc-backup-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_vpc_backup_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_vpc_backup_policy.arn
}

## Restore policies

resource "aws_iam_policy" "veeam_aws_ec2_restore_policy" {
  name        = "veeam-aws-ec2-restore-policy"
  description = "Veeam Backup for AWS permissions to perform EC2 restore operations."

  policy = file("veeam-aws-ec2-restore-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_ec2_restore_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_ec2_restore_policy.arn
}

resource "aws_iam_policy" "veeam_aws_rds_restore_policy" {
  name        = "veeam-aws-rds-restore-policy"
  description = "Veeam Backup for AWS permissions to perform RDS restore operations."

  policy = file("veeam-aws-rds-restore-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_rds_restore_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_rds_restore_policy.arn
}

resource "aws_iam_policy" "veeam_aws_efs_restore_policy" {
  name        = "veeam-aws-efs-restore-policy"
  description = "Veeam Backup for AWS permissions to perform EFS restore operations."

  policy = file("veeam-aws-efs-restore-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_efs_restore_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_efs_restore_policy.arn
}

resource "aws_iam_policy" "veeam_aws_vpc_restore_policy" {
  name        = "veeam-aws-vpc-restore-policy"
  description = "Veeam Backup for AWS permissions to perform VPC configuration restore operations."

  policy = file("veeam-aws-vpc-restore-policy.json")
}

resource "aws_iam_role_policy_attachment" "veeam_aws_vpc_restore_policy_attachment" {
  role       = aws_iam_role.veeam_aws_default_role.name
  policy_arn = aws_iam_policy.veeam_aws_vpc_restore_policy.arn
}

### VPC Resources

resource "aws_vpc" "veeam_aws_vpc" {
  cidr_block           = var.vpc_cidr_block_ipv4
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "veeam-aws-vpc"
  }
}

resource "aws_internet_gateway" "veeam_aws_igw" {
  tags = {
    Name = "veeam-aws-igw"
  }
}

resource "aws_internet_gateway_attachment" "veeam_aws_igw_attachment" {
  internet_gateway_id = aws_internet_gateway.veeam_aws_igw.id
  vpc_id              = aws_vpc.veeam_aws_vpc.id
}

resource "aws_route_table" "veeam_aws_route_table" {
  vpc_id = aws_vpc.veeam_aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.veeam_aws_igw.id
  }

  tags = {
    Name = "veeam-aws-rt"
  }
}

resource "aws_route_table_association" "veeam_aws_route_table_association" {
  subnet_id      = aws_subnet.veeam_aws_subnet.id
  route_table_id = aws_route_table.veeam_aws_route_table.id
}

resource "aws_subnet" "veeam_aws_subnet" {
  vpc_id                  = aws_vpc.veeam_aws_vpc.id
  cidr_block              = var.subnet_cidr_block_ipv4
  map_public_ip_on_launch = true

  tags = {
    Name = "veeam-aws-subnet"
  }
}

resource "aws_security_group" "veeam_aws_security_group" {
  name        = "veeam-aws-security-group"
  description = "Access to Veeam Backup for AWS appliance"
  vpc_id      = aws_vpc.veeam_aws_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.veeam_aws_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_endpoint" "veeam_aws_s3_endpoint" {
  vpc_id            = aws_vpc.veeam_aws_vpc.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.veeam_aws_route_table.id]
}

resource "aws_eip" "veeam_aws_eip" {
  count = var.elastic_ip ? 1 : 0
  vpc   = true
}

resource "aws_eip_association" "veeam_aws_eip_association" {
  count = var.elastic_ip ? 1 : 0
  instance_id   = aws_instance.veeam_aws_instance.id
  allocation_id = aws_eip.veeam_aws_eip[0].id
}

### EC2 Resources

resource "aws_instance" "veeam_aws_instance" {
  ami                    = local.veeam_aws_instance_ami
  instance_type          = var.veeam_aws_instance_type
  iam_instance_profile   = aws_iam_instance_profile.veeam_aws_instance_profile.name
  subnet_id              = aws_subnet.veeam_aws_subnet.id
  vpc_security_group_ids = [aws_security_group.veeam_aws_security_group.id]

  tags = {
    Name = "veeam-aws-demo"
  }

  user_data = join("\n", [aws_iam_role.veeam_aws_instance_role.arn, aws_iam_role.veeam_aws_default_role.arn])
}

### S3 bucket to store Veeam backups

resource "aws_s3_bucket" "veeam_aws_bucket" {
  bucket = "veeam-aws-bucket-demo"

  force_destroy = true
  # IMPORTANT! The bucket and all contents will be deleted upon running a `terraform destory` command

}

resource "aws_s3_bucket_acl" "veeam_aws_bucket_acl" {
  bucket = aws_s3_bucket.veeam_aws_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "veeam_aws_bucket_public_access_block" {
  bucket = aws_s3_bucket.veeam_aws_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "veeam_aws_bucket_ownership_controls" {
  bucket = aws_s3_bucket.veeam_aws_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "veeam_aws_bucket_lockdown_policy" {
  bucket = aws_s3_bucket.veeam_aws_bucket.id
  policy = data.aws_iam_policy_document.veeam_aws_bucket_lockdown_policy_document.json
}

data "aws_iam_policy_document" "veeam_aws_bucket_lockdown_policy_document" {
  statement {
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.veeam_aws_bucket.arn,
      "${aws_s3_bucket.veeam_aws_bucket.arn}/*",
    ]

    condition {
      test = "StringNotLike"
      variable = "aws:userId"

      values = [
        "${var.admin_role_id}:*",
        var.admin_user_id,
        "${aws_iam_role.veeam_aws_default_role.unique_id}:*"
      ]
    }
  }
}

### Outputs

output "veeam_aws_instance_id" {
  description = "The instance ID of the Veeam Backup for AWS EC2 instance"
  value       = aws_instance.veeam_aws_instance.id
}

output "veeam_aws_instance_role_arn" {
  description = "The ARN of the instance role attached to the Veeam Backup for AWS EC2 instance"
  value = aws_iam_role.veeam_aws_instance_role.arn
}