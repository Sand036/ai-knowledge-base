-- AI Knowledge Base: hardened Supabase PostgreSQL + pgvector schema
-- Before applying: confirm embedding model dimension. This example uses 1536.
-- RLS is enabled but policies are intentionally absent (default deny).

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

-- Profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name VARCHAR(150),
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Workspaces. owner_id is canonical; ownership transfer is disabled in MVP.
CREATE TABLE public.workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(150) NOT NULL,
  description TEXT,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- User stories currently specify Owner, Admin, Member; no Viewer.
CREATE TABLE public.workspace_members (
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'member')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, user_id)
);
CREATE INDEX idx_workspace_members_user ON public.workspace_members(user_id);
-- A workspace can have only one owner membership. This complements the trigger
-- that protects the canonical owner_id membership from demotion/deletion.
CREATE UNIQUE INDEX uq_workspace_one_owner
  ON public.workspace_members (workspace_id)
  WHERE role = 'owner';

-- Documents. file_type is canonical; MIME is constrained to match it.
-- Application/server must normalize MIME before INSERT: e.g. TXT values such as
-- 'text/plain;charset=UTF-8' are accepted as input but stored canonically as
-- 'text/plain'. Client-provided MIME is untrusted; validate file content too.
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  name VARCHAR(255) NOT NULL,
  file_type VARCHAR(20) NOT NULL CHECK (file_type IN ('pdf', 'txt')),
  mime_type VARCHAR(100) NOT NULL CHECK (
    (file_type = 'pdf' AND mime_type = 'application/pdf') OR
    (file_type = 'txt' AND mime_type = 'text/plain')
  ),
  size_bytes BIGINT NOT NULL CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  storage_path TEXT NOT NULL UNIQUE,
  checksum VARCHAR(128),
  status VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  error_message TEXT,
  error_category VARCHAR(30) CHECK (
    error_category IS NULL OR error_category IN (
      'document_invalid', 'unsupported_format', 'extraction_failed',
      'embedding_failed', 'provider_error', 'system_error',
      'storage_error', 'unknown'
    )
  ),
  retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_documents_id_workspace UNIQUE (id, workspace_id)
);
CREATE INDEX idx_documents_workspace_status ON public.documents(workspace_id, status);
CREATE INDEX idx_documents_uploaded_by ON public.documents(uploaded_by);

-- Chunks: composite FK prevents document/workspace mismatch.
-- No separate workspace_id FK; composite FK enforces both identity and workspace.
CREATE TABLE public.document_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL,
  workspace_id UUID NOT NULL,
  chunk_index INTEGER NOT NULL CHECK (chunk_index >= 0),
  content TEXT NOT NULL,
  page_number INTEGER CHECK (page_number IS NULL OR page_number > 0),
  embedding extensions.vector(1536), -- Change to model's actual dimension before migration.
  embedding_model VARCHAR(100),
  token_count INTEGER CHECK (token_count IS NULL OR token_count >= 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (document_id, chunk_index),
  CONSTRAINT fk_chunks_document_workspace
    FOREIGN KEY (document_id, workspace_id)
    REFERENCES public.documents(id, workspace_id) ON DELETE CASCADE
);
CREATE INDEX idx_document_chunks_workspace ON public.document_chunks(workspace_id);
-- UNIQUE(document_id, chunk_index) already has document_id as its leading index key.
-- HNSW with vector type supports up to 2000 dimensions.
CREATE INDEX idx_document_chunks_embedding
  ON public.document_chunks USING hnsw (embedding extensions.vector_cosine_ops);

-- Conversations
CREATE TABLE public.conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL DEFAULT 'New conversation',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_conversations_user_updated ON public.conversations(user_id, updated_at DESC);
CREATE INDEX idx_conversations_workspace ON public.conversations(workspace_id);

-- Messages
CREATE TABLE public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  model_name VARCHAR(100),
  prompt_tokens INTEGER CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens INTEGER CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  latency_ms INTEGER CHECK (latency_ms IS NULL OR latency_ms >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_messages_conversation_created ON public.messages(conversation_id, created_at);

-- Sources. Snapshot citation text remains after source chunk is deleted.
CREATE TABLE public.message_sources (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  chunk_id UUID REFERENCES public.document_chunks(id) ON DELETE SET NULL,
  citation_index INTEGER NOT NULL CHECK (citation_index > 0),
  source_document_name TEXT NOT NULL,
  snippet TEXT,
  page_number INTEGER CHECK (page_number IS NULL OR page_number > 0),
  similarity_score REAL CHECK (similarity_score IS NULL OR similarity_score BETWEEN -1 AND 1),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, citation_index)
);
CREATE INDEX idx_message_sources_chunk ON public.message_sources(chunk_id);
-- No separate message_id index: UNIQUE(message_id, citation_index) covers it.

-- Feedback: one vote per user per answer.
CREATE TABLE public.feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating VARCHAR(20) NOT NULL CHECK (rating IN ('helpful', 'unhelpful')),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, user_id)
);

-- Usage events: successful AI requests are counted; limit breaches are logged too.
CREATE TABLE public.usage_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workspace_id UUID REFERENCES public.workspaces(id) ON DELETE SET NULL,
  event_type VARCHAR(40) NOT NULL CHECK (event_type IN (
    'ai_request', 'rate_limit_exceeded', 'daily_quota_exceeded'
  )),
  request_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_usage_events_user_type_created
  ON public.usage_events(user_id, event_type, created_at DESC);
CREATE INDEX idx_usage_events_workspace_created
  ON public.usage_events(workspace_id, created_at DESC);

-- updated_at trigger function and triggers
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_workspaces_updated_at BEFORE UPDATE ON public.workspaces
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_documents_updated_at BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_conversations_updated_at BEFORE UPDATE ON public.conversations
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Create profile when Supabase Auth creates a user.
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (NEW.id, NEW.raw_user_meta_data ->> 'display_name',
          NEW.raw_user_meta_data ->> 'avatar_url')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_auth_user_created_profile
  AFTER INSERT ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();

-- Add workspace owner as a member automatically.
CREATE OR REPLACE FUNCTION public.add_workspace_owner_membership()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (workspace_id, user_id) DO UPDATE SET role = 'owner';
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_workspace_add_owner
  AFTER INSERT ON public.workspaces FOR EACH ROW
  EXECUTE FUNCTION public.add_workspace_owner_membership();

-- Prevent ownership transfer in MVP so owner_id and owner membership cannot diverge.
CREATE OR REPLACE FUNCTION public.prevent_workspace_owner_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id THEN
    RAISE EXCEPTION 'Workspace ownership transfer is not supported in MVP';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_prevent_workspace_owner_change
  BEFORE UPDATE OF owner_id ON public.workspaces FOR EACH ROW
  EXECUTE FUNCTION public.prevent_workspace_owner_change();

-- Prevent deleting/demoting the canonical owner membership.
CREATE OR REPLACE FUNCTION public.protect_workspace_owner_membership()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  canonical_owner UUID;
BEGIN
  SELECT owner_id INTO canonical_owner
  FROM public.workspaces WHERE id = OLD.workspace_id;

  IF OLD.user_id = canonical_owner THEN
    IF TG_OP = 'DELETE' THEN
      RAISE EXCEPTION 'Workspace owner membership cannot be deleted';
    ELSIF NEW.role <> 'owner' OR NEW.user_id <> OLD.user_id
           OR NEW.workspace_id <> OLD.workspace_id THEN
      RAISE EXCEPTION 'Workspace owner membership cannot be changed or demoted';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_protect_workspace_owner_membership
  BEFORE UPDATE OR DELETE ON public.workspace_members FOR EACH ROW
  EXECUTE FUNCTION public.protect_workspace_owner_membership();

-- Every inserted message refreshes conversation activity timestamp.
-- DB trigger selected rather than app code, to cover all insertion paths.
CREATE OR REPLACE FUNCTION public.touch_conversation_on_message()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- SECURITY DEFINER lets this trigger update the conversation even when the
  -- inserting user has no direct UPDATE policy on conversations.
  UPDATE public.conversations
     SET updated_at = now()
   WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_message_updates_conversation
  AFTER INSERT ON public.messages FOR EACH ROW
  EXECUTE FUNCTION public.touch_conversation_on_message();

-- QUOTA CONCURRENCY ADR: usage_events is an audit log, not by itself an atomic
-- quota gate. Do not implement quota as a simple count-then-insert: concurrent
-- requests can both pass. Enforce quota atomically (e.g. per-user advisory lock
-- inside a transaction / a locked counter row / a dedicated database function)
-- before calling the AI provider, then record the usage event.

-- RLS enabled for every application table. No policies in this migration:
-- browser-facing anon/authenticated requests are denied by default.
-- Add explicit, reviewed policies in a subsequent migration.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_events ENABLE ROW LEVEL SECURITY;
