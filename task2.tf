provider "aws" {
  region = "ap-south-1"
  profile = "Ajay"
}

resource "tls_private_key" "task2_key"  {
  algorithm = "RSA"
}

resource "aws_key_pair" "keypair1" {
  key_name = var.key
  public_key = tls_private_key.task2_key.public_key_openssh

  depends_on = [
   tls_private_key.task2_key
  ]
}

resource "local_file" "download_key" {
  content = tls_private_key.task2_key.private_key_pem
  filename = "${var.key}.pem"
  depends_on = [
   tls_private_key.task2_key
  ]
}

resource "aws_security_group" "sg" {
  description = "Security Group to allow NFS, SSH and HTTP"
  name = var.security
  vpc_id = var.id_vpc
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_http_ssh_nfs"
  }
}

resource "aws_s3_bucket" "t1_bucket" {
  bucket = var.S3
  acl    = "public-read"

  tags = {
    Name        = "task2_s3"
  }
}

resource "aws_s3_bucket_object" "t1_bucket_object" {
  bucket = aws_s3_bucket.t1_bucket.bucket
  key    = "task2.jpg"
  source = "C:/Users/Ajay Pathak/Desktop/Cloud/task2/task2.jpg"
  acl = "public-read"
}

locals {
  s3_origin_id = aws_s3_bucket.t1_bucket.id
}

resource "aws_cloudfront_distribution" "task2_cf" {
  origin {
    domain_name = aws_s3_bucket.t1_bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "cloudfront_s3"

  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Environment = "t1_cf"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
 
resource "aws_efs_file_system" "efs" {
  creation_token = "task2-efs"

  tags = {
    Name = "task2"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_instance.task2_os.subnet_id
  security_groups = [ "${aws_security_group.sg.id}" ]
}

resource "aws_instance" "task2_os" {
  ami           = var.ami_id
  instance_type = var.inst_type
  key_name = aws_key_pair.keypair1.key_name
  security_groups = [ aws_security_group.sg.name ]
  tags = {
    Name = "task2"
  }
}

resource "null_resource" "setup_efs" {
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task2_key.private_key_pem
    host     = aws_instance.task2_os.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
      "echo '${aws_efs_mount_target.mount_target.mount_target_dns_name}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab",
      "sudo mount -a",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Ajaypathak372/cloud-task2.git  /var/www/html/", 
    ]
  }
}

resource "null_resource"  "nullremote" {
  depends_on = [	
  null_resource.setup_efs
  ]
  
  connection {
    type = "ssh"
    port = 22
    user = "ec2-user"
    private_key = tls_private_key.task2_key.private_key_pem
    host = aws_instance.task2_os.public_ip
  }
  provisioner "remote-exec"{
    inline = [
    "sudo su << EOF",
    "echo '<img src='https://${aws_cloudfront_distribution.task2_cf.domain_name}/${aws_s3_bucket_object.t1_bucket_object.key}' width=400 height=800>' >> /var/www/html/task2.html",
    "EOF",
    ]
	
  }
}

output "ip" {
  value = aws_instance.task2_os.public_ip
}
/*
output "subnet" {
  value = aws_efs_mount_target.mount_target
}
*/