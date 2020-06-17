// declaring profile
provider "aws" {
region = "ap-south-1"
profile = "default"

}

//Create a security group
resource "aws_security_group" "sg" {
  name        = "security_group"
  description = "Allow http and ssh"
  vpc_id      ="vpc-f7f2ef9f"
  
  ingress {
    description = "SSH protocol"
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
    Name = "Security_group"
  }
}


// Create an ec2 instance
resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "key1"
  security_groups = [ "security_group" ]


connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Arushi Gupta/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
tags = {
    Name = "task1"
  }

}



//launch ebs
resource "aws_ebs_volume" "volume" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1

  tags = {
    Name = "task1"
  }
}


//Attach volume
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.volume.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}


resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Arushi Gupta/Downloads/key1.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Arushi1800/nss-login.git /var/www/html/"
    ]
  }
}

//Create S3 bucket, and copy/deploy the images from github repository into the s3 bucket and change the permission to public readable.

resource "null_resource" "nulllocal2"  {
  provisioner "local-exec" {
      command = "git clone https://github.com/Arushi1800/nss-login.git ./gitcode"
    }
}  



resource "aws_s3_bucket" "task1" {
  bucket = "scholarsdentask1"
  acl    = "public-read"
  tags = {
      Name = "scholarsdentask1"
      Environment = "Dev"
  }
}


resource "aws_s3_bucket_object" "bucket_obj1" {
  bucket = "${aws_s3_bucket.task1.id}"
  key    = "circle-cropped.png"
  source = "./gitcode/images/circle-cropped.png"
  acl	 = "public-read"
}

resource "aws_s3_bucket_object" "bucket_obj2" {
  bucket = "${aws_s3_bucket.task1.id}"
  key    = "favicon.ico"
  source = "./gitcode/images/favicon.ico"
  acl	 = "public-read"
}




//Create a cloud front Distribution using the s3 bucket
locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.task1.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  
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


  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


output "cloudfront_ip_addr"{
value = aws_cloudfront_distribution.s3_distribution.domain_name
}

resource "null_resource" "nullocal1" {
	provisioner "local-exec" {
		command = "echo ${aws_cloudfront_distribution.s3_distribution.domain_name} > cdndomain.txt"
	}
}








