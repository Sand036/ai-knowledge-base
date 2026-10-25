# AI Knowledge Base

Ứng dụng web full-stack cho phép tải tài liệu lên, tổ chức thành kho tri thức (workspace) và đặt câu hỏi bằng ngôn ngữ tự nhiên. Hệ thống dùng RAG để trả lời dựa trên tài liệu, kèm trích dẫn nguồn có thể kiểm chứng.

## Tech stack

Next.js (App Router) · TypeScript · Tailwind CSS · shadcn/ui · Supabase (PostgreSQL + pgvector, Auth, Storage; migration bằng Supabase CLI) · Zod · Vitest · Playwright

## Cấu trúc thư mục

```
ai-knowledge-base/
├── .github/workflows/   # CI: lint, type-check, test
├── docs/                # user stories, ERD, kiến trúc, API, quyết định kỹ thuật
├── supabase/            # migrations SQL (schema, RLS, index vector), seed dữ liệu demo
├── scripts/             # script phụ trợ (vd: chạy bộ đánh giá RAG)
├── src/
│   ├── app/             # Routing: pages và API route handlers (MỎNG, chỉ điều phối)
│   │   ├── (auth)/      # route công khai: đăng nhập, đăng ký
│   │   ├── (app)/       # route cần đăng nhập
│   │   └── api/         # endpoint REST
│   ├── components/      # Giao diện, chia theo tính năng
│   ├── server/          # Code CHỈ chạy ở server
│   │   ├── auth/        # lấy user hiện tại, kiểm tra quyền (một chỗ duy nhất)
│   │   ├── db/          # Supabase client (server) và truy vấn
│   │   ├── services/    # nghiệp vụ: workspace, document, chat
│   │   ├── ingestion/   # extract → chunk → embed → pipeline
│   │   ├── retrieval/   # tìm top-k chunk, dựng context
│   │   ├── ai/          # gọi embedding và LLM, prompt
│   │   ├── storage/     # lưu/xóa file gốc
│   │   └── security/    # validate file, rate limit
│   ├── schemas/         # Zod schemas dùng chung client/server
│   ├── lib/             # env, errors, constants
│   └── types/           # gồm database.types.ts (sinh bằng `supabase gen types`)
├── tests/               # unit, integration, e2e, fixtures, bộ câu hỏi đánh giá RAG
├── .env.example
└── README.md
```

## Quy tắc kiến trúc

1. `route.ts` không gọi database hay LLM trực tiếp; luôn đi qua `server/services`.
2. Mọi kiểm tra quyền nằm trong `server/auth`.
3. Mọi lời gọi AI đi qua `server/ai`.
4. Không đưa API key vào biến có tiền tố `NEXT_PUBLIC_`.

## Chạy local

_Sẽ bổ sung ở tuần 2._

## Database

Schema được quản lý bằng **migration SQL thuần** trong `supabase/migrations/`
(bảng, ràng buộc `CHECK`, `ON DELETE CASCADE`, RLS, extension `vector`, index HNSW).
Lý do chọn: xem `docs/decisions/001-database-tooling.md`.
