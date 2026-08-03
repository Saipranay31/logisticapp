-- ═══════════════════════════════════════════════
-- Porter Admin Seed Data
-- Password: admin1234 (BCrypt hash below - generated with rounds=10)
-- Email: admin@porter.com
-- ═══════════════════════════════════════════════

-- First delete the old admin if it exists to allow reinsertion
DELETE FROM users WHERE email = 'admin@porter.com';

INSERT INTO users (id, phone, email, password_hash, full_name, role, is_active, created_at, updated_at)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  '0000000000',
  'admin@porter.com',
  '$2a$10$2lK2sYRmf9gI9u0lN9xQHe9l9M6qN8b3p0r8sQwF7vD6kL4j5tUXy',
  'Porter Admin',
  'ADMIN',
  true,
  NOW(),
  NOW()
);
