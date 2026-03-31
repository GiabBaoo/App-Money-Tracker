# Tài liệu Yêu cầu - Giao diện Cài đặt và Chế độ Tối

## Giới thiệu

Tính năng này bổ sung màn hình cài đặt với khả năng chuyển đổi chế độ tối (dark mode) cho toàn bộ ứng dụng, đồng thời cải thiện tính nhất quán của biểu tượng giữa trang chủ và trang ví.

## Thuật ngữ

- **App**: Ứng dụng quản lý thu chi "App Thu Chi"
- **Settings_Screen**: Màn hình cài đặt mới cho phép người dùng điều chỉnh các tùy chọn ứng dụng
- **Dark_Mode**: Chế độ hiển thị tối với nền tối và văn bản sáng
- **Light_Mode**: Chế độ hiển thị sáng với nền sáng và văn bản tối
- **Theme_Service**: Dịch vụ quản lý chủ đề hiện có của ứng dụng
- **Profile_Screen**: Màn hình hồ sơ người dùng (trang chủ)
- **Wallet_Screen**: Màn hình ví hiển thị các giao dịch
- **Transaction_Icon**: Biểu tượng đại diện cho danh mục giao dịch
- **Icon_Style**: Kiểu hiển thị của biểu tượng bao gồm màu sắc và kích thước

## Yêu cầu

### Yêu cầu 1: Màn hình Cài đặt

**User Story:** Là người dùng, tôi muốn có một màn hình cài đặt riêng, để tôi có thể quản lý các tùy chọn ứng dụng một cách tập trung.

#### Tiêu chí chấp nhận

1. THE Settings_Screen SHALL hiển thị tiêu đề "Cài đặt" ở đầu màn hình
2. THE Settings_Screen SHALL có nút quay lại để điều hướng về màn hình trước
3. THE Settings_Screen SHALL hiển thị danh sách các tùy chọn cài đặt có thể cuộn
4. THE Settings_Screen SHALL được truy cập từ Profile_Screen thông qua một mục menu mới
5. THE Settings_Screen SHALL áp dụng màu nền và màu văn bản phù hợp với chế độ hiển thị hiện tại

### Yêu cầu 2: Chuyển đổi Chế độ Tối

**User Story:** Là người dùng, tôi muốn bật/tắt chế độ tối, để tôi có thể sử dụng ứng dụng thoải mái hơn trong điều kiện ánh sáng khác nhau.

#### Tiêu chí chấp nhận

1. THE Settings_Screen SHALL hiển thị một công tắc (switch) để bật/tắt Dark_Mode
2. WHEN người dùng bật công tắc Dark_Mode, THE App SHALL chuyển sang Dark_Mode trong vòng 300ms
3. WHEN người dùng tắt công tắc Dark_Mode, THE App SHALL chuyển sang Light_Mode trong vòng 300ms
4. THE Theme_Service SHALL lưu trạng thái Dark_Mode vào bộ nhớ cục bộ
5. WHEN App khởi động, THE Theme_Service SHALL khôi phục trạng thái Dark_Mode đã lưu
6. THE Settings_Screen SHALL hiển thị biểu tượng mặt trăng khi Dark_Mode được bật
7. THE Settings_Screen SHALL hiển thị biểu tượng mặt trời khi Light_Mode được bật
8. THE Settings_Screen SHALL hiển thị văn bản mô tả "Tiết kiệm pin và dịu mắt hơn" cho tùy chọn Dark_Mode

### Yêu cầu 3: Áp dụng Chế độ Tối cho Toàn bộ Ứng dụng

**User Story:** Là người dùng, tôi muốn chế độ tối được áp dụng nhất quán trên tất cả màn hình, để tôi có trải nghiệm thống nhất trong toàn bộ ứng dụng.

#### Tiêu chí chấp nhận

1. WHEN Dark_Mode được bật, THE App SHALL áp dụng nền tối (màu #121212) cho tất cả các màn hình
2. WHEN Dark_Mode được bật, THE App SHALL áp dụng văn bản sáng cho tất cả nội dung văn bản
3. WHEN Dark_Mode được bật, THE App SHALL áp dụng màu nền tối (màu #1E1E1E) cho các thẻ và container
4. WHEN Light_Mode được bật, THE App SHALL áp dụng nền sáng (màu trắng) cho tất cả các màn hình
5. WHEN Light_Mode được bật, THE App SHALL áp dụng văn bản tối cho tất cả nội dung văn bản
6. THE App SHALL duy trì màu chủ đề chính (màu #438883) trong cả hai chế độ
7. THE App SHALL cập nhật màu của BottomNavigationBar phù hợp với chế độ hiện tại
8. THE App SHALL cập nhật màu của AppBar phù hợp với chế độ hiện tại

### Yêu cầu 4: Nhất quán Biểu tượng Giao dịch

**User Story:** Là người dùng, tôi muốn biểu tượng giao dịch hiển thị nhất quán giữa trang chủ và trang ví, để tôi có thể dễ dàng nhận diện các danh mục giao dịch.

#### Tiêu chí chấp nhận

1. WHEN một giao dịch thu nhập được hiển thị trên Profile_Screen, THE Transaction_Icon SHALL sử dụng màu xanh lá (màu #24A869)
2. WHEN một giao dịch chi tiêu được hiển thị trên Profile_Screen, THE Transaction_Icon SHALL sử dụng màu đỏ (màu #F95B51)
3. THE Transaction_Icon trên Profile_Screen SHALL có cùng kích thước với Transaction_Icon trên Wallet_Screen
4. THE Transaction_Icon trên Profile_Screen SHALL có cùng kiểu nền (background) với Transaction_Icon trên Wallet_Screen
5. FOR ALL giao dịch, màu Transaction_Icon trên Profile_Screen SHALL khớp với màu Transaction_Icon trên Wallet_Screen cho cùng loại giao dịch
6. THE Transaction_Icon SHALL hiển thị rõ ràng trong cả Dark_Mode và Light_Mode

### Yêu cầu 5: Tích hợp Menu Cài đặt

**User Story:** Là người dùng, tôi muốn truy cập màn hình cài đặt từ trang hồ sơ, để tôi có thể dễ dàng tìm thấy các tùy chọn cấu hình.

#### Tiêu chí chấp nhận

1. THE Profile_Screen SHALL hiển thị một mục menu mới có tên "Cài đặt"
2. THE Profile_Screen SHALL hiển thị biểu tượng bánh răng (settings icon) cho mục menu "Cài đặt"
3. WHEN người dùng nhấn vào mục menu "Cài đặt", THE App SHALL điều hướng đến Settings_Screen
4. THE Profile_Screen SHALL hiển thị mục menu "Cài đặt" phía trên mục "Đăng nhập và bảo mật"
5. THE Profile_Screen SHALL áp dụng cùng kiểu hiển thị cho mục menu "Cài đặt" như các mục menu khác

### Yêu cầu 6: Trải nghiệm Người dùng Mượt mà

**User Story:** Là người dùng, tôi muốn việc chuyển đổi chế độ tối diễn ra mượt mà, để tôi có trải nghiệm sử dụng thoải mái.

#### Tiêu chí chấp nhận

1. WHEN chế độ hiển thị thay đổi, THE App SHALL hiển thị hiệu ứng chuyển tiếp mượt mà
2. THE App SHALL hoàn thành việc chuyển đổi chế độ trong vòng 300ms
3. WHILE chế độ đang chuyển đổi, THE App SHALL duy trì khả năng tương tác của người dùng
4. THE App SHALL không hiển thị màn hình trắng hoặc nhấp nháy trong quá trình chuyển đổi
5. WHEN người dùng quay lại Settings_Screen, THE App SHALL hiển thị trạng thái công tắc Dark_Mode chính xác
