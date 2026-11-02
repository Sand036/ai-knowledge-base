# AI Workspace — User Stories

## Glossary \& Scope

* **Workspace**: một workspace (kho tri thức) trong toàn bộ dự án. Từ `workspace` được dùng thống nhất trong user stories, database schema, API và giao diện.
* **MVP**: chỉ hỗ trợ tài liệu **PDF và TXT**. DOCX nằm ngoài MVP và được xem xét ở giai đoạn sau.
* **Priority**: `P0` = bắt buộc cho MVP; `P1` = quan trọng nhưng có thể hoàn thành sau MVP; `P2` = cải tiến/để giai đoạn sau.
* **Giới hạn MVP mặc định**: file upload tối đa 10 MB; truy xuất ngữ nghĩa lấy tối đa 5 chunks; mật khẩu tối thiểu 8 ký tự.
## Epic A — Authentication \& Authorization
Quản lý tài khoản, phiên đăng nhập và quyền truy cập dữ liệu.

### US-01: Đăng ký tài khoản — Priority: P0
User Story
As a Visitor, I want to register an account so that I can use the AI Workspace system.

Acceptance Criteria

1. Người dùng có thể đăng ký bằng email và mật khẩu.
2. Email phải đúng định dạng; mật khẩu phải có ít nhất 8 ký tự.
3. Hệ thống thông báo lỗi nếu email đã được sử dụng.
4. Mật khẩu không được lưu dưới dạng văn bản thuần.
5. Khi đăng ký thành công, người dùng được thông báo và có thể đăng nhập hoặc được chuyển vào ứng dụng theo luồng xác thực đã chọn.

### US-02: Đăng nhập và đăng xuất — Priority: P0
User Story
As a registered User, I want to log in and log out securely so that I can access my workspaces safely.

Acceptance Criteria

1. Người dùng có thể đăng nhập bằng thông tin hợp lệ.
2. Thông tin sai phải tạo thông báo lỗi phù hợp.
3. Các trang riêng tư chỉ truy cập được khi có phiên đăng nhập hợp lệ.
4. Người dùng có thể đăng xuất.
5. Sau khi đăng xuất, người dùng không thể tiếp tục sử dụng phiên đã kết thúc để truy cập tài nguyên được bảo vệ.

### US-03: Phân quyền truy cập dữ liệu — Priority: P0
User Story
As a User, I want the system to enforce access permissions so that other users cannot access my private data.

Acceptance Criteria

1. Server kiểm tra quyền trước mỗi thao tác đọc, tạo, sửa hoặc xóa dữ liệu.
2. Người dùng chỉ truy cập được các workspace mà họ có quyền sử dụng.
3. Thay đổi ID trên URL hoặc API không được giúp người dùng vượt qua phân quyền.
4. Người dùng không có quyền không thể xem tài liệu, lịch sử trò chuyện hoặc kết quả tìm kiếm của người khác.
5. Quyền truy cập được kiểm tra tại server, không chỉ bằng cách ẩn nút trên giao diện.
## Epic B — Workspace Management
Quản lý các kho tri thức chứa tài liệu của người dùng.

### US-04: Tạo workspace — Priority: P0
User Story
As a User, I want to create a workspace so that I can organize documents by topic or purpose.

Acceptance Criteria

1. Người dùng có thể nhập tên workspace.
2. Tên bắt buộc và được kiểm tra tính hợp lệ.
3. workspace được liên kết với người tạo.
4. Sau khi tạo thành công, workspace xuất hiện trong danh sách của người dùng.
5. Người dùng không thể xem hoặc chỉnh sửa workspace nếu không có quyền.

### US-05: Xem và cập nhật workspace — Priority: P1
User Story
As a User, I want to view and update my workspace information so that I can manage my knowledge collections.

Acceptance Criteria

1. Người dùng có thể xem thông tin chi tiết của workspace.
2. Người có quyền chỉnh sửa có thể cập nhật tên và mô tả.
3. Hệ thống kiểm tra dữ liệu đầu vào trước khi lưu.
4. Thay đổi được hiển thị sau khi cập nhật thành công.
5. Người không có quyền chỉnh sửa không thể cập nhật thông tin.

### US-06: Xóa workspace — Priority: P1
User Story
As a Workspace Owner, I want to delete a workspace so that I can remove collections that are no longer needed.

Acceptance Criteria

1. Hệ thống yêu cầu xác nhận trước khi xóa.
2. Chỉ người có quyền phù hợp mới được xóa.
3. Tài liệu, các đoạn văn bản đã xử lý, embeddings và dữ liệu liên quan phải được xử lý nhất quán.
4. Dữ liệu đã xóa không được tiếp tục xuất hiện trong kết quả truy xuất của AI.
5. Nếu thao tác xóa thất bại một phần, hệ thống phải có cơ chế ghi nhận và xử lý lại.
## Epic C — Document Management
Tải lên, xem trạng thái xử lý và quản lý tài liệu.

### US-07: Tải tài liệu lên — Priority: P0
User Story
As a User, I want to upload documents to a workspace so that the AI can use their content to answer my questions.

Acceptance Criteria

1. Trong MVP, người dùng chỉ có thể tải lên tệp PDF hoặc TXT; DOCX không được hỗ trợ.
2. Người dùng phải có quyền truy cập workspace đích.
3. Hệ thống chỉ chấp nhận PDF/TXT hợp lệ có kích thước tối đa 10 MB (10 × 1024 × 1024 bytes); tệp vượt giới hạn hoặc sai định dạng bị từ chối và hiển thị lỗi.
4. Tệp được lưu trữ an toàn và có metadata tương ứng trong database.
5. Sau khi tải lên, tài liệu có trạng thái ban đầu là Pending
6. Nếu tải lên thất bại, hệ thống hiển thị thông báo phù hợp.

### US-08: Xem danh sách tài liệu và trạng thái xử lý — Priority: P0
User Story
As a User, I want to view uploaded documents and their processing statuses so that I know which documents are ready for AI queries.

Acceptance Criteria

1. Người dùng chỉ xem được các tài liệu mà họ có quyền truy cập.
2. Danh sách hiển thị tên tệp, loại tệp, thời gian tải lên và trạng thái.
3. Hệ thống hỗ trợ các trạng thái Pending, Processing, Completed và Failed.
4. Giao diện thể hiện trạng thái đang tải, danh sách trống và lỗi khi cần.
5. Trạng thái được cập nhật khi quá trình xử lý thay đổi.

### US-09: Xem chi tiết tài liệu — Priority: P1
User Story
As a User, I want to view document details so that I can inspect its metadata and processing status.

Acceptance Criteria

1. Người dùng có thể xem tên, loại tệp, thời gian tải lên và trạng thái xử lý.
2. Nếu xử lý thất bại, hệ thống hiển thị thông tin lỗi ở mức an toàn và dễ hiểu.
3. Chỉ người có quyền mới được xem chi tiết tài liệu.
4. Thông tin nội bộ nhạy cảm hoặc khóa API không được hiển thị.

### US-10: Xóa tài liệu — Priority: P0
User Story
As a User, I want to delete a document so that outdated or unnecessary information is no longer used by the AI.

Acceptance Criteria

1. Người dùng có quyền có thể yêu cầu xóa tài liệu.
2. Hệ thống yêu cầu xác nhận trước khi xóa.
3. Tệp gốc, metadata, chunks và embeddings được xóa hoặc vô hiệu hóa nhất quán.
4. Tài liệu đã xóa không được sử dụng trong các truy vấn mới.
5. Hệ thống ghi nhận lỗi và cho phép xử lý lại nếu thao tác xóa chưa hoàn tất.

### US-11: Xử lý lại tài liệu thất bại — Priority: P1
User Story
As a User, I want to retry processing a failed document so that I can make it available to the AI without uploading it again.

Acceptance Criteria

1. Chỉ tài liệu đủ điều kiện xử lý lại mới có thể được retry.
2. Hệ thống cập nhật trạng thái và bắt đầu lại pipeline.
3. Quá trình retry không tạo chunks hoặc embeddings trùng lặp.
4. Lỗi mới được ghi nhận để hỗ trợ chẩn đoán.
5. Hệ thống giới hạn retry hợp lý để tránh lặp vô hạn.
## Epic D — Document Processing \& Semantic Search
Chuyển tài liệu thành dữ liệu mà AI có thể truy xuất.

### US-12: Trích xuất văn bản và chia chunks — Priority: P0
User Story
As a System, I want to extract and split document content into manageable chunks so that the AI can retrieve relevant information efficiently.

Acceptance Criteria

1. Hệ thống trích xuất văn bản từ PDF và TXT; DOCX không thuộc phạm vi MVP.
2. Văn bản được chuẩn hóa trước khi chia thành các chunks.
3. Mỗi chunk lưu thông tin liên kết với tài liệu gốc, thứ tự và số trang nếu có.
4. Tài liệu rỗng, lỗi định dạng hoặc không đọc được phải được đánh dấu thất bại.
5. Các chunks phải giữ đúng liên kết với workspace và tài liệu tương ứng.

### US-13: Tạo embeddings — Priority: P0
User Story
As a System, I want to generate vector embeddings for document chunks so that semantically related content can be found.

Acceptance Criteria

1. Mỗi chunk hợp lệ được chuyển thành vector embedding.
2. Kích thước vector phải tương thích với cấu hình vector database.
3. Embeddings được liên kết với chunk và tài liệu gốc.
4. Lỗi từ embedding provider được ghi nhận và xử lý an toàn.
5. Chỉ những chunks đã xử lý thành công mới được đưa vào tìm kiếm.

### US-14: Tìm kiếm ngữ nghĩa — Priority: P0
User Story
As a User, I want the system to retrieve semantically relevant document chunks so that I can find information even when my wording differs from the source text.

Acceptance Criteria

1. Hệ thống chuyển câu hỏi thành embedding khi cần.
2. Hệ thống truy xuất tối đa 5 chunks có độ tương đồng cao nhất; chỉ lấy chunks vượt ngưỡng similarity được cấu hình.
3. Kết quả bị giới hạn trong workspace được chọn và phạm vi quyền của người dùng.
4. Tài liệu đã xóa hoặc chưa xử lý xong không xuất hiện trong kết quả.
5. Nếu không có kết quả phù hợp, hệ thống trả về trạng thái không tìm thấy bằng chứng thích hợp.
## Epic E — AI Question Answering (RAG)
Đây là chức năng trọng tâm của dự án: kết hợp truy xuất tài liệu với mô hình ngôn ngữ để trả lời câu hỏi.

### US-15: Đặt câu hỏi cho AI — Priority: P0
User Story
As a User, I want to ask natural-language questions about my workspace so that I can obtain answers from my documents quickly.

Acceptance Criteria

1. Người dùng có thể chọn workspace và nhập câu hỏi.
2. Câu hỏi không được để trống.
3. Server xác thực quyền truy cập trước khi truy xuất tài liệu.
4. Hệ thống tìm chunks liên quan, gửi ngữ cảnh phù hợp cho LLM và tạo câu trả lời.
5. Câu hỏi, câu trả lời và các nguồn được sử dụng được lưu lại theo thiết kế hệ thống.
6. Giao diện hiển thị trạng thái đang xử lý, kết quả hoặc lỗi.
7. Nếu dịch vụ AI gặp sự cố hoặc vượt giới hạn sử dụng, hệ thống thông báo phù hợp.

### US-16: Hiển thị trích dẫn nguồn — Priority: P0
User Story
As a User, I want to see citations for AI-generated answers so that I can verify the information against the original documents.

Acceptance Criteria

1. Câu trả lời hiển thị nguồn tài liệu thực sự được sử dụng làm ngữ cảnh.
2. Nguồn hiển thị tên tệp và đoạn trích liên quan.
3. Nếu có thông tin số trang, hệ thống hiển thị số trang.
4. Người dùng có thể xác định nguồn tương ứng với nội dung trả lời.
5. Nguồn trích dẫn được đối chiếu với các chunks thực tế ở phía server, không chỉ tin vào nội dung do LLM tự tạo.
6. Không được hiển thị nguồn mà người dùng không có quyền truy cập.

### US-17: Xử lý câu hỏi không đủ bằng chứng — Priority: P0
User Story
As a User, I want the AI to tell me when my documents do not contain enough evidence so that I do not rely on unsupported answers.

Acceptance Criteria

1. Nếu không tìm thấy nội dung liên quan, hệ thống thông báo rằng chưa đủ thông tin để trả lời.
2. AI được hướng dẫn chỉ sử dụng bằng chứng từ ngữ cảnh được cung cấp.
3. Hệ thống không được tạo trích dẫn giả.
4. Khi bằng chứng yếu hoặc mâu thuẫn, câu trả lời cần thể hiện sự không chắc chắn phù hợp.
5. Giao diện có thể gợi ý người dùng diễn đạt lại câu hỏi hoặc bổ sung tài liệu.

### US-18: Xem lịch sử trò chuyện — Priority: P1
User Story
As a User, I want to view previous conversations so that I can revisit questions and answers about my documents.

Acceptance Criteria

1. Người dùng có thể xem danh sách cuộc trò chuyện của mình.
2. Tin nhắn được hiển thị theo đúng thứ tự thời gian.
3. Mỗi cuộc trò chuyện được liên kết với workspace tương ứng.
4. Người dùng không thể xem lịch sử của người khác.
5. Nguồn trích dẫn được xử lý phù hợp nếu tài liệu nguồn bị xóa hoặc quyền truy cập thay đổi.

### US-19: Đánh giá câu trả lời AI — Priority: P2
User Story
As a User, I want to provide feedback on AI answers so that answer quality can be evaluated and improved.

Acceptance Criteria

1. Người dùng có thể đánh dấu câu trả lời hữu ích hoặc không hữu ích.
2. Người dùng có thể nhập nhận xét tùy chọn.
3. Feedback được liên kết với câu trả lời tương ứng.
4. Người dùng không thể chỉnh sửa feedback của người khác.
5. Hệ thống có thể tổng hợp feedback để đánh giá chất lượng sản phẩm.
## Epic F — Workspace Collaboration
Các chức năng này phù hợp khi muốn mở rộng dự án từ kho tri thức cá nhân thành nền tảng làm việc nhóm.

### US-20: Mời thành viên vào workspace — Priority: P2
User Story
As a Workspace Owner, I want to invite other users to my workspace so that we can share knowledge and collaborate.

Acceptance Criteria

1. Owner có thể gửi lời mời đến email hợp lệ.
2. Lời mời có trạng thái như Pending, Accepted hoặc Expired.
3. Chỉ người nhận phù hợp mới có thể chấp nhận lời mời.
4. Hệ thống ngăn lời mời trùng lặp không cần thiết.
5. Chỉ người có quyền mới được mời thành viên.

### US-21: Quản lý vai trò thành viên — Priority: P2
User Story
As a Workspace Owner, I want to assign roles to workspace members so that each person has the appropriate level of access.

Acceptance Criteria

1. Hệ thống hỗ trợ các vai trò như Owner, Admin và Member.
2. Mỗi vai trò có quyền được định nghĩa rõ ràng.
3. Chỉ người có quyền quản lý mới được thay đổi vai trò.
4. Thành viên không thể tự nâng quyền của mình.
5. Hệ thống bảo vệ quyền sở hữu, tránh vô tình xóa hoặc hạ quyền Owner cuối cùng.
## Epic G — Monitoring, Evaluation \& Cost Control

### US-22: Theo dõi pipeline xử lý tài liệu — Priority: P1
User Story
As a Developer or Administrator, I want to monitor document-processing jobs so that I can identify and resolve failures.

Acceptance Criteria

1. Hệ thống ghi nhận trạng thái và thời điểm xử lý.
2. Lỗi được ghi nhận với thông tin đủ để chẩn đoán.
3. Log không chứa API key, mật khẩu hoặc thông tin bí mật.
4. Tài liệu lỗi có thể được xác định và xử lý lại theo quyền phù hợp.
5. Các lỗi hệ thống được phân biệt với lỗi do tài liệu không hợp lệ.

### US-23: Đánh giá chất lượng RAG — Priority: P1
User Story
As a Developer, I want to evaluate the RAG pipeline using a test dataset so that I can measure retrieval and answer quality before releasing the application.

Acceptance Criteria

1. Có bộ câu hỏi kiểm thử kèm nguồn tài liệu mong đợi.
2. Hệ thống có thể đánh giá việc truy xuất nguồn đúng, chẳng hạn Recall@k hoặc Hit Rate@k.
3. Có thể kiểm tra tính đúng đắn của trích dẫn và mức độ câu trả lời bám sát bằng chứng.
4. Kết quả đánh giá được lưu hoặc xuất để so sánh giữa các lần thay đổi.
5. Báo cáo nêu rõ giới hạn của bộ dữ liệu và phương pháp đánh giá.

### US-24: Theo dõi độ trễ và chi phí AI — Priority: P1
User Story
As a System Administrator, I want to monitor AI usage and request latency so that I can control costs and maintain acceptable performance.

Acceptance Criteria

1. Hệ thống ghi nhận thời gian xử lý mỗi truy vấn.
2. Nếu provider cung cấp thông tin token usage, hệ thống ghi nhận số token đầu vào và đầu ra.
3. Chi phí được ước tính theo bảng giá và mô hình đã cấu hình.
4. Không ghi log thông tin xác thực hoặc dữ liệu nhạy cảm không cần thiết.

### US-25: Giới hạn tần suất và quota sử dụng AI — Priority: P0
User Story
As a System Administrator, I want to enforce request rate limits and usage quotas so that I can prevent abuse and control AI service costs.

Acceptance Criteria

1. Với MVP, mỗi người dùng được phép gửi tối đa 10 yêu cầu hỏi AI trong mỗi cửa sổ 1 phút.
2. Với MVP, mỗi người dùng được phép gửi tối đa 100 yêu cầu hỏi AI trong một ngày UTC.
3. Khi vượt rate limit hoặc quota, server từ chối yêu cầu và trả về HTTP 429 cùng thông báo có thể hiểu được.
4. Các yêu cầu bị từ chối do giới hạn không gọi embedding provider hoặc LLM.
5. Bộ đếm được kiểm tra ở server; người dùng không thể vượt giới hạn bằng cách gọi API trực tiếp hoặc thay đổi giao diện.
6. Hệ thống ghi nhận user, thời điểm và loại giới hạn bị chạm, nhưng không ghi API key hoặc dữ liệu bí mật.
7. Các giới hạn 10 yêu cầu/phút và 100 yêu cầu/ngày có thể được cấu hình qua biến môi trường hoặc cấu hình server mà không cần sửa logic nghiệp vụ.
## Epic H — User Experience

## Epic H — User Experience

### US-26: Hiển thị trạng thái loading, empty và error — Priority: P0
User Story
As a User, I want clear feedback during every important operation so that I understand what the system is doing and how to recover from errors.

Acceptance Criteria

1. Các thao tác bất đồng bộ có trạng thái loading phù hợp.
2. Danh sách trống có hướng dẫn hành động tiếp theo.
3. Lỗi được diễn đạt rõ ràng, không để lộ thông tin nội bộ.
4. Các thao tác có thể thử lại sẽ cung cấp lựa chọn retry.
5. Giao diện hoạt động tốt trên desktop và mobile.

### US-27: Tìm kiếm và lọc danh sách tài liệu — Priority: P2
User Story
As a User, I want to search and filter documents so that I can quickly find the files I need.

Acceptance Criteria

1. Người dùng có thể tìm kiếm tài liệu theo tên tệp.
2. Người dùng có thể lọc theo trạng thái hoặc loại tệp.
3. Kết quả chỉ chứa tài liệu người dùng được phép truy cập.
4. Hệ thống hiển thị trạng thái khi không có kết quả.
5. Việc tìm kiếm và lọc không làm thay đổi dữ liệu gốc.
