provider "aws" {
  region = "ap-south-1"
  profile = "ashwani"
}
resource "aws_security_group" "my_firewall" {
  name        = "my_firewall"
  description = "My Customised Security Group"
  ingress {
    description = "SSH "
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP Protocol"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "my_firewall"
  }
}
resource "tls_private_key" "task_keypair" {
  algorithm   = "RSA"
  
}
output "ssh_key" {
    value = tls_private_key.task_keypair.public_key_openssh
}

output "pem_key" {
     value = tls_private_key.task_keypair.public_key_pem
}

resource "aws_key_pair" "task_keypair"{
      key_name = "task_keypair"
      public_key = tls_private_key.task_keypair.public_key_openssh
}

resource "aws_instance" "task_os" {
     ami = "ami-0447a12f28fddb066"
     instance_type = "t2.micro"
     availability_zone = "ap-south-1a"
     key_name = aws_key_pair.task_keypair.key_name
     security_groups = ["${aws_security_group.my_firewall.tags.Name}"]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_keypair.private_key_pem
    host     = aws_instance.task_os.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
     
 
     tags = {
              Name= "task_os" 
            }
}

resource "aws_ebs_volume" "task_ebs" {
  availability_zone = "ap-south-1a"
  size              = 1

  tags = {
    Name = "task_ebs"
  }
}

resource "aws_volume_attachment" "task_ebsattach" {
  device_name = "/dev/sde"
  volume_id   = aws_ebs_volume.task_ebs.id
  instance_id = aws_instance.task_os.id
  force_detach = true
}
output "myos_ip" {
  value = aws_instance.task_os.public_ip
}

resource "null_resource" "os_ip" {
  provisioner "local-exec" {
   command = "echo  ${aws_instance.task_os.public_ip} > publicip.txt"
  	}
}
resource "null_resource" "partition"  {

depends_on = [
    aws_volume_attachment.task_ebsattach
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task_keypair.private_key_pem
    host     = aws_instance.task_os.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvde",
      "sudo mount  /dev/xvde  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/ashwani7273/cloud_task1.git /var/www/html"
    ]
  }
}
output "myos_ip1" {
  value = aws_instance.task_os.public_ip
}

resource "aws_s3_bucket" "task1bucket1" {
  bucket = "task1bucket1"
  acl    = "public-read"
  versioning {
    enabled = true
  }
  tags = {
    Name        = "task1bucket1"
    Environment = "Personal"
  }
}


resource "aws_cloudfront_distribution" "s3_distribution" {
          enabled = true
          is_ipv6_enabled = true
          default_root_object = "first.html"

   origin {
    domain_name = "${aws_s3_bucket.task1bucket1.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.task1bucket1.id}"
     }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.task1bucket1.id}"
   
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

  viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 7200
    max_ttl                = 86400
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "null_resource" "nullremoteaccess" {
  depends_on=[
    null_resource.partition
  ]
}