# Part 4 - Advanced 3 - Chi phí và Free Tier Hygiene

Free Tier hỗ trợ tốt để học, nhưng để tài nguyên “mồ côi” có thể vẫn tốn tiền thật.

## Thiết lập cảnh báo ngân sách

1. AWS Console -> Billing -> **Budgets** -> Create budget
2. Chọn *Cost budget*, đặt mức `$5/tháng`
3. Tạo cảnh báo ở mức 80% và 100% về email

## Checklist dọn dẹp hằng ngày

```bash
# Danh sách EC2 đang chạy
aws ec2 describe-instances \
  --query "Reservations[].Instances[].[InstanceId,State.Name,InstanceType]" \
  --output table

# Volume chưa gắn vào instance nào
aws ec2 describe-volumes --filters Name=status,Values=available

# Elastic IP chưa gắn
aws ec2 describe-addresses \
  --query "Addresses[?AssociationId==null]"
```

## Quy tắc sống còn cho lab

- Nếu nghỉ học lâu: **terminate instance** thay vì chỉ stop.
- `Stopped` không tốn compute, nhưng EBS volume vẫn có phí lưu trữ.
- Xoá tài nguyên không dùng ngay trong ngày để tránh quên.

## Gợi ý thực hành tốt

- Đặt tag rõ ràng cho tài nguyên: `Project=Sgroup`, `Env=training`, `Owner=<name>`.
- Dùng tag để lọc và dọn tài nguyên nhanh.

