# Part 4 - Advanced 5 - Infrastructure as Code (Preview)

Tạo hạ tầng bằng thao tác tay trên Console phù hợp để học.  
Nhưng với team thật, click tay khó review, khó lặp lại, khó audit.

Giải pháp: mô tả hạ tầng bằng code (IaC), ví dụ Terraform.

## Ví dụ Terraform tối thiểu

```hcl
# main.tf
provider "aws" {
  region = "ap-southeast-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "training" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = "training-key"

  tags = {
    Name = "training-session-2"
  }
}
```

Các lệnh cơ bản:

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Ý nghĩa với người mới

- `plan` giúp xem trước thay đổi trước khi áp dụng.
- `code review` cho infra giống như review code app.
- `destroy` giúp dọn lab sạch, tránh phí phát sinh.

Thông điệp quan trọng:
- Click tay tốt cho học.
- Hạ tầng production nên đi theo dạng code để minh bạch và ổn định.

