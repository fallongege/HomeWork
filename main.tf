provider "aws" {
  region = var.myregion
}
#Create an S3 bucket backend to manage the state file
terraform {
  backend "s3" {
    bucket = "esere-gege"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
# Creating a kms key for S3 bucket  sever_side encryption
resource "aws_kms_key" "kingskey" {
  description         = "This key is used to encrypt bucket objects"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.mypolicy.json
}
#create an S3 bucket
resource "aws_s3_bucket" "mybucket" {
  bucket = var.bucketname
  acl    = "private"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
    Terraform   = true
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.kingskey.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}
# Get the account id of the current user dynamically.
data "aws_caller_identity" "current" {}

#Create a key policy that will be attached to the kms key which grants the root user full-access to the kms key.
data "aws_iam_policy_document" "mypolicy" {
  statement {
    sid    = "allow root access to this key"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "ec2s3role" {
  name = "role_to_access_jjtech-fallongegehomework_bucket"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "ec2s3policy" {
  name = "jjtech-fallongegehomework_bucket_access_policy"
  role = aws_iam_role.ec2s3role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "S3DeleteGetPutObject",
        "Action" : [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:s3:::jjtech-fallongegehomework"
      }
    ]
  })
}
resource "aws_iam_instance_profile" "ec2s3role" {
  name = "Ec2-Role-For-jjtech-fallongegehomework-Bucket"
  role = aws_iam_role.ec2s3role.name
}
data "aws_subnet" "mysubnet" {
  filter {
    name   = "tag:Name"
    values = ["SSMsubnet"]
  }
}
data "aws_security_group" "mySG" {
  id = "sg-0880e9871044f63dc"

}

resource "aws_instance" "ec2s3server" {
  ami                         = var.ami
  instance_type               = var.myinstance_type
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.mysubnet.id
  key_name                    = var.mykeypair
  vpc_security_group_ids      = [data.aws_security_group.mySG.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2s3role.id
user_data                   = file("copy.sh")
  tags = {
    Name = "HomeWorkServer"
  }
}

