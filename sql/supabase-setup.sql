-- ============================================================
-- Supabase: configuración del vector store para el agente de soporte
-- Ejecutar en Supabase > SQL Editor (una sola vez)
-- ============================================================

-- 1) Extensión pgvector
create extension if not exists vector;

-- 2) Tabla de documentos (1024 dimensiones = mistral-embed de Mistral)
create table if not exists documents (
  id bigserial primary key,
  content text,            -- fragmento (chunk) de texto
  metadata jsonb,          -- p. ej. {"fuente": "base-de-conocimiento-tostadero"}
  embedding vector(1024)   -- vector del fragmento
);

-- 3) Función de búsqueda por similitud que usa n8n (queryName = match_documents)
create or replace function match_documents (
  query_embedding vector(1024),
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- 4) (Opcional) Índice para acelerar la búsqueda cuando haya muchos documentos
-- create index on documents using hnsw (embedding vector_cosine_ops);

-- ------------------------------------------------------------
-- Antes de RE-ingestar el documento (para no duplicar fragmentos):
-- truncate table documents restart identity;
-- ------------------------------------------------------------
