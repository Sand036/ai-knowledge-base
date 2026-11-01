-- =====================================================================
-- schema_smoke_test.sql
-- Kiểm thử nhanh ràng buộc và trigger của schema AI Knowledge Base.
--
-- Cách chạy (sau khi đã apply migration vào database LOCAL):
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f tests/db/schema_smoke_test.sql
--
-- - Toàn bộ chạy trong 1 transaction và ROLLBACK ở cuối: không để lại dữ liệu.
-- - Mỗi test ghi PASS/FAIL vào bảng tạm, cuối file in bảng kết quả.
-- - Nếu có test FAIL, lệnh psql thoát với mã lỗi (dùng được trong CI).
-- - KHÔNG chạy trên database production.
-- =====================================================================
BEGIN;

CREATE TEMP TABLE test_results (
  id     serial PRIMARY KEY,
  label  text    NOT NULL,
  passed boolean NOT NULL,
  detail text
);

-- ---- Hàm trợ giúp -------------------------------------------------------

-- Câu lệnh PHẢI thành công
CREATE FUNCTION pg_temp.expect_ok(p_label text, p_stmt text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_stmt;
  INSERT INTO test_results(label, passed) VALUES (p_label, true);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_results(label, passed, detail)
  VALUES (p_label, false, 'bị từ chối ngoài ý muốn: ' || SQLSTATE || ' ' || SQLERRM);
END $$;

-- Câu lệnh PHẢI bị database từ chối với đúng mã lỗi (SQLSTATE)
--   23503 = foreign_key_violation, 23505 = unique_violation,
--   23514 = check_violation,       P0001  = RAISE EXCEPTION từ trigger
CREATE FUNCTION pg_temp.expect_error(p_label text, p_stmt text, p_sqlstate text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE caught text;
BEGIN
  BEGIN
    EXECUTE p_stmt;
  EXCEPTION WHEN OTHERS THEN
    caught := SQLSTATE;
  END;
  IF caught IS NULL THEN
    INSERT INTO test_results(label, passed, detail)
    VALUES (p_label, false, 'lẽ ra phải bị từ chối nhưng đã THÀNH CÔNG');
  ELSIF caught = p_sqlstate THEN
    INSERT INTO test_results(label, passed) VALUES (p_label, true);
  ELSE
    INSERT INTO test_results(label, passed, detail)
    VALUES (p_label, false, 'bị từ chối nhưng sai lỗi: ' || caught || ' (mong đợi ' || p_sqlstate || ')');
  END IF;
END $$;

-- Truy vấn trả về 1 giá trị boolean, PHẢI là true
CREATE FUNCTION pg_temp.expect_true(p_label text, p_query text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE r boolean;
BEGIN
  EXECUTE p_query INTO r;
  INSERT INTO test_results(label, passed, detail)
  VALUES (p_label, coalesce(r, false), CASE WHEN coalesce(r, false) THEN NULL ELSE 'điều kiện trả về ' || coalesce(r::text, 'NULL') END);
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_results(label, passed, detail)
  VALUES (p_label, false, SQLSTATE || ' ' || SQLERRM);
END $$;

-- ---- Dữ liệu nền --------------------------------------------------------
-- 3 người dùng A, B, C
INSERT INTO auth.users (id) VALUES
  ('a0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000002'),
  ('c0000000-0000-0000-0000-000000000003');

-- WS-A (chủ A), WS-B (chủ B), WS-C (chủ C; dùng để thử xóa workspace)
INSERT INTO public.workspaces (id, name, owner_id) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'WS-A', 'a0000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-0000-0000-000000000002', 'WS-B', 'b0000000-0000-0000-0000-000000000002'),
  ('c1000000-0000-0000-0000-000000000003', 'WS-C', 'c0000000-0000-0000-0000-000000000003');

-- Tài liệu + chunk hợp lệ trong WS-A
INSERT INTO public.documents (id, workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
VALUES ('d1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001', 'a.pdf', 'pdf', 'application/pdf', 1000, 'ws-a/a.pdf');
INSERT INTO public.document_chunks (id, document_id, workspace_id, chunk_index, content)
VALUES ('e1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001',
        'a1000000-0000-0000-0000-000000000001', 0, 'noi dung chunk');

-- Hội thoại + tin nhắn trợ lý trong WS-A
INSERT INTO public.conversations (id, workspace_id, user_id)
VALUES ('f1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000001');
INSERT INTO public.messages (id, conversation_id, role, content)
VALUES ('f2000000-0000-0000-0000-000000000001', 'f1000000-0000-0000-0000-000000000001', 'assistant', 'tra loi');

-- ---- Nhóm 1: trigger "nối dây" -----------------------------------------
SELECT pg_temp.expect_true('T01 tạo user -> tự có profile',
  $q$ SELECT count(*) = 3 FROM public.profiles
      WHERE id IN ('a0000000-0000-0000-0000-000000000001',
                   'b0000000-0000-0000-0000-000000000002',
                   'c0000000-0000-0000-0000-000000000003') $q$);

SELECT pg_temp.expect_true('T02 tạo workspace -> chủ tự thành member role owner',
  $q$ SELECT count(*) = 1 FROM public.workspace_members
      WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
        AND user_id = 'a0000000-0000-0000-0000-000000000001' AND role = 'owner' $q$);

-- ---- Nhóm 2: khóa ngoại kép (workspace_id không được lệch) -------------
SELECT pg_temp.expect_error('T03 chunk gắn SAI workspace bị từ chối',
  $q$ INSERT INTO public.document_chunks (document_id, workspace_id, chunk_index, content)
      VALUES ('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000002', 1, 'ro ri') $q$,
  '23503');

SELECT pg_temp.expect_ok('T04 chunk đúng workspace được chấp nhận',
  $q$ INSERT INTO public.document_chunks (document_id, workspace_id, chunk_index, content)
      VALUES ('d1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 1, 'ok') $q$);

-- ---- Nhóm 3: ràng buộc dữ liệu tài liệu --------------------------------
SELECT pg_temp.expect_error('T05 pdf nhưng mime text/plain bị từ chối',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'pdf', 'text/plain', 10, 'p/1') $q$,
  '23514');

SELECT pg_temp.expect_error('T06 file_type docx bị từ chối (ngoài MVP)',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'docx', 'application/pdf', 10, 'p/2') $q$,
  '23514');

SELECT pg_temp.expect_error('T07 size_bytes = 0 bị từ chối',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'pdf', 'application/pdf', 0, 'p/3') $q$,
  '23514');

SELECT pg_temp.expect_error('T08 size 10MB + 1 byte bị từ chối',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'pdf', 'application/pdf', 10485761, 'p/4') $q$,
  '23514');

SELECT pg_temp.expect_ok('T09 size đúng 10MB (biên) được chấp nhận',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'pdf', 'application/pdf', 10485760, 'p/5') $q$);

SELECT pg_temp.expect_ok('T10 txt với mime text/plain được chấp nhận',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'txt', 'text/plain', 10, 'p/6') $q$);

-- Theo thiết kế: server PHẢI chuẩn hóa mime trước khi INSERT. Test này khóa hành vi đó.
SELECT pg_temp.expect_error('T11 mime chưa chuẩn hóa (text/plain;charset=UTF-8) bị từ chối',
  $q$ INSERT INTO public.documents (workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'x', 'txt', 'text/plain;charset=UTF-8', 10, 'p/7') $q$,
  '23514');

-- ---- Nhóm 4: bảo vệ quyền sở hữu workspace -----------------------------
SELECT pg_temp.expect_error('T12 đổi owner_id bị chặn',
  $q$ UPDATE public.workspaces SET owner_id = 'b0000000-0000-0000-0000-000000000002'
      WHERE id = 'a1000000-0000-0000-0000-000000000001' $q$, 'P0001');

SELECT pg_temp.expect_error('T13 hạ cấp owner membership bị chặn',
  $q$ UPDATE public.workspace_members SET role = 'member'
      WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
        AND user_id = 'a0000000-0000-0000-0000-000000000001' $q$, 'P0001');

SELECT pg_temp.expect_error('T14 xóa owner membership bị chặn',
  $q$ DELETE FROM public.workspace_members
      WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
        AND user_id = 'a0000000-0000-0000-0000-000000000001' $q$, 'P0001');

SELECT pg_temp.expect_ok('T15 thêm B làm member của WS-A',
  $q$ INSERT INTO public.workspace_members (workspace_id, user_id, role)
      VALUES ('a1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'member') $q$);

SELECT pg_temp.expect_error('T16 nâng B lên owner (owner thứ hai) bị chặn',
  $q$ UPDATE public.workspace_members SET role = 'owner'
      WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
        AND user_id = 'b0000000-0000-0000-0000-000000000002' $q$, '23505');

SELECT pg_temp.expect_error('T17 role viewer không tồn tại trong MVP',
  $q$ UPDATE public.workspace_members SET role = 'viewer'
      WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
        AND user_id = 'b0000000-0000-0000-0000-000000000002' $q$, '23514');

SELECT pg_temp.expect_error('T18 xóa user đang là owner bị RESTRICT chặn',
  $q$ DELETE FROM auth.users WHERE id = 'a0000000-0000-0000-0000-000000000001' $q$, '23503');

-- ---- Nhóm 5: citation, feedback, usage ---------------------------------
INSERT INTO public.message_sources (message_id, chunk_id, citation_index, source_document_name, snippet, page_number)
VALUES ('f2000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 1, 'a.pdf', 'trich doan', 3);

SELECT pg_temp.expect_ok('T19 xóa chunk nguồn (không lỗi)',
  $q$ DELETE FROM public.document_chunks WHERE id = 'e1000000-0000-0000-0000-000000000001' $q$);

SELECT pg_temp.expect_true('T20 sau khi xóa chunk: citation còn, chunk_id = NULL, snapshot nguyên vẹn',
  $q$ SELECT count(*) = 1 FROM public.message_sources
      WHERE message_id = 'f2000000-0000-0000-0000-000000000001'
        AND chunk_id IS NULL AND source_document_name = 'a.pdf' AND snippet = 'trich doan' $q$);

SELECT pg_temp.expect_ok('T21 feedback lần đầu',
  $q$ INSERT INTO public.feedback (message_id, user_id, rating)
      VALUES ('f2000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'helpful') $q$);

SELECT pg_temp.expect_error('T22 vote trùng (cùng user, cùng message) bị chặn',
  $q$ INSERT INTO public.feedback (message_id, user_id, rating)
      VALUES ('f2000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'unhelpful') $q$,
  '23505');

SELECT pg_temp.expect_error('T23 rating ngoài danh sách bị từ chối',
  $q$ INSERT INTO public.feedback (message_id, user_id, rating)
      VALUES ('f2000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000002', 'great') $q$,
  '23514');

SELECT pg_temp.expect_error('T24 usage_events: event_type lạ bị từ chối',
  $q$ INSERT INTO public.usage_events (user_id, event_type)
      VALUES ('a0000000-0000-0000-0000-000000000001', 'hack') $q$, '23514');

SELECT pg_temp.expect_ok('T25 usage_events: ghi sự kiện hợp lệ',
  $q$ INSERT INTO public.usage_events (user_id, workspace_id, event_type)
      VALUES ('a0000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'ai_request') $q$);

-- ---- Nhóm 6: updated_at tự cập nhật ------------------------------------
-- (Trong 1 transaction now() đứng yên, nên ta cố tình ghi ngày cũ: trigger phải ghi đè.)
SELECT pg_temp.expect_true('T26 trigger updated_at ghi đè giá trị cũ',
  $q$ WITH u AS (
        UPDATE public.documents SET updated_at = '2000-01-01', name = 'a2.pdf'
         WHERE id = 'd1000000-0000-0000-0000-000000000001' RETURNING updated_at)
      SELECT updated_at > '2001-01-01' FROM u $q$);

-- ---- Nhóm 7: xóa workspace (US-06) lan truyền đúng ---------------------
INSERT INTO public.documents (id, workspace_id, uploaded_by, name, file_type, mime_type, size_bytes, storage_path)
VALUES ('d2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000003',
        'c0000000-0000-0000-0000-000000000003', 'c.pdf', 'pdf', 'application/pdf', 100, 'ws-c/c.pdf');
INSERT INTO public.document_chunks (document_id, workspace_id, chunk_index, content)
VALUES ('d2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000003', 0, 'c');
INSERT INTO public.conversations (id, workspace_id, user_id)
VALUES ('f1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000003',
        'c0000000-0000-0000-0000-000000000003');
INSERT INTO public.messages (conversation_id, role, content)
VALUES ('f1000000-0000-0000-0000-000000000003', 'user', 'hoi');

SELECT pg_temp.expect_ok('T27 xóa WS-C (trigger bảo vệ owner không được cản cascade)',
  $q$ DELETE FROM public.workspaces WHERE id = 'c1000000-0000-0000-0000-000000000003' $q$);

SELECT pg_temp.expect_true('T28 sau khi xóa WS-C: không còn documents/chunks/members/conversations/messages',
  $q$ SELECT (SELECT count(*) FROM public.documents WHERE workspace_id = 'c1000000-0000-0000-0000-000000000003')
           + (SELECT count(*) FROM public.document_chunks WHERE workspace_id = 'c1000000-0000-0000-0000-000000000003')
           + (SELECT count(*) FROM public.workspace_members WHERE workspace_id = 'c1000000-0000-0000-0000-000000000003')
           + (SELECT count(*) FROM public.conversations WHERE workspace_id = 'c1000000-0000-0000-0000-000000000003')
           + (SELECT count(*) FROM public.messages WHERE conversation_id = 'f1000000-0000-0000-0000-000000000003') = 0 $q$);

-- ---- Nhóm 8: RLS bật đủ ------------------------------------------------
SELECT pg_temp.expect_true('T29 RLS bật trên cả 10 bảng ứng dụng',
  $q$ SELECT count(*) = 10 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relrowsecurity
         AND c.relname IN ('profiles','workspaces','workspace_members','documents','document_chunks',
                           'conversations','messages','message_sources','feedback','usage_events') $q$);

-- ---- Nhóm 9: trigger chạy dưới quyền người dùng bị RLS hạn chế ---------
-- Giả lập 1 người dùng ứng dụng: chỉ có policy tối thiểu, KHÔNG có quyền UPDATE
-- trên conversations và KHÔNG xem được bảng workspaces.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_tester') THEN
    CREATE ROLE app_tester NOLOGIN;
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO app_tester;
GRANT INSERT ON public.messages TO app_tester;
GRANT SELECT, DELETE ON public.workspace_members TO app_tester;
-- Supabase mặc định cấp quyền bảng cho anon/authenticated và để RLS quyết định dòng nào
-- nhìn thấy được. Ta mô phỏng đúng như vậy: có quyền SELECT trên workspaces nhưng
-- KHÔNG có policy nào => mọi truy vấn của app_tester trả về 0 dòng (không báo lỗi).
GRANT SELECT ON public.workspaces TO app_tester;
CREATE POLICY t_msg_ins ON public.messages FOR INSERT TO app_tester WITH CHECK (true);
CREATE POLICY t_wm_sel  ON public.workspace_members FOR SELECT TO app_tester USING (true);
CREATE POLICY t_wm_del  ON public.workspace_members FOR DELETE TO app_tester USING (true);

-- T30: gửi tin nhắn bằng quyền app_tester -> conversations.updated_at vẫn được cập nhật
ALTER TABLE public.conversations DISABLE TRIGGER trg_conversations_updated_at;
UPDATE public.conversations SET updated_at = '2000-01-01'
 WHERE id = 'f1000000-0000-0000-0000-000000000001';
ALTER TABLE public.conversations ENABLE TRIGGER trg_conversations_updated_at;

DO $$
BEGIN
  SET LOCAL ROLE app_tester;
  BEGIN
    INSERT INTO public.messages (conversation_id, role, content)
    VALUES ('f1000000-0000-0000-0000-000000000001', 'user', 'cau hoi moi');
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    INSERT INTO test_results(label, passed, detail)
    VALUES ('T30 tin nhắn mới cập nhật conversations.updated_at khi người gửi bị hạn chế RLS', false, SQLSTATE || ' ' || SQLERRM);
    RETURN;
  END;
  RESET ROLE;
  INSERT INTO test_results(label, passed, detail)
  SELECT 'T30 tin nhắn mới cập nhật conversations.updated_at khi người gửi bị hạn chế RLS',
         c.updated_at > '2001-01-01',
         CASE WHEN c.updated_at > '2001-01-01' THEN NULL ELSE 'updated_at vẫn là ngày cũ: UPDATE trong trigger bị RLS lọc mất 0 dòng, không báo lỗi' END
    FROM public.conversations c WHERE c.id = 'f1000000-0000-0000-0000-000000000001';
END $$;

-- T31: người dùng bị hạn chế RLS cố xóa owner membership -> trigger bảo vệ vẫn phải chặn
DO $$
DECLARE n int;
BEGIN
  SET LOCAL ROLE app_tester;
  BEGIN
    DELETE FROM public.workspace_members
     WHERE workspace_id = 'a1000000-0000-0000-0000-000000000001'
       AND user_id = 'a0000000-0000-0000-0000-000000000001';
    GET DIAGNOSTICS n = ROW_COUNT;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    INSERT INTO test_results(label, passed, detail)
    VALUES ('T31 trigger bảo vệ owner vẫn hoạt động khi người xóa bị hạn chế RLS', SQLSTATE = 'P0001',
            CASE WHEN SQLSTATE = 'P0001' THEN NULL ELSE SQLSTATE || ' ' || SQLERRM END);
    RETURN;
  END;
  RESET ROLE;
  INSERT INTO test_results(label, passed, detail)
  VALUES ('T31 trigger bảo vệ owner vẫn hoạt động khi người xóa bị hạn chế RLS', false,
          'owner membership đã bị XÓA (' || n || ' dòng): trigger đọc bảng workspaces bị RLS lọc nên bảo vệ tắt âm thầm');
END $$;

-- ---- Kết quả ------------------------------------------------------------
SELECT label, CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS result, detail
  FROM test_results ORDER BY id;

SELECT count(*) FILTER (WHERE passed) AS passed, count(*) FILTER (WHERE NOT passed) AS failed
  FROM test_results;

DO $$
DECLARE f int;
BEGIN
  SELECT count(*) INTO f FROM test_results WHERE NOT passed;
  IF f > 0 THEN RAISE EXCEPTION '% test thất bại', f; END IF;
END $$;

ROLLBACK;
