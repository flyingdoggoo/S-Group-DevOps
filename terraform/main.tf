# 1. Khai báo Provider (Sử dụng AWS)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1" # Chọn region Singapore cho gần Việt Nam
  # Yêu cầu: Bạn đã cài đặt aws-cli và chạy `aws configure` để nhập Access Key
}

# 2. Tạo Tường lửa (Security Group)
resource "aws_security_group" "my_app_sg" {
  name        = "my-app-sg"
  description = "Mo port 80, 443 cho Caddy và 22 de SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cho phép server được gọi ra Internet để tải các package
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

# 3. Tạo máy chủ (EC2 Instance)
resource "aws_instance" "app_server" {
  ami           = "ami-0df7a207aea202642" # Hệ điều hành Ubuntu 22.04 LTS
  instance_type = "t3.micro"              # Loại server nhỏ, đủ để chạy lab
  
  # Gắn tường lửa đã tạo ở trên vào máy chủ này
  vpc_security_group_ids = [aws_security_group.my_app_sg.id]

  # Script tự động chạy MỘT LẦN DUY NHẤT khi server khởi tạo xong
  user_data = <<-EOF
              #!/bin/bash
              # Cài đặt Docker và Docker Compose
              apt-get update -y
              apt-get install -y docker.io docker-compose-v2 git
              systemctl start docker
              systemctl enable docker

              # Kéo source code (Giả sử bạn đã push repo lên Github)
              # Lưu ý: Thay URL bên dưới bằng URL repo Github của bạn
              git clone https://github.com/flyingdoggoo/S-Group-DevOps.git /home/ubuntu/project
              
              cd /home/ubuntu/project/my-app
              
              # Khởi chạy dự án bằng file compose.yaml của bạn
              docker compose up -d
              EOF

  tags = {
    Name = "MyApp-Production-Server"
  }
}

# 4. In ra địa chỉ IP của server sau khi tạo xong
output "server_public_ip" {
  value       = aws_instance.app_server.public_ip
  description = "Truy cap vao IP nay tren trinh duyet de xem ung dung"
}
