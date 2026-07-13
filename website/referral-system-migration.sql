CREATE TABLE IF NOT EXISTS referral_admin_codes (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(100) NOT NULL,
  label VARCHAR(160) NOT NULL,
  issued_by VARCHAR(100) NULL,
  rewards JSON NOT NULL,
  max_uses INT UNSIGNED NULL,
  expires_at DATETIME(3) NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL,
  UNIQUE KEY referral_admin_codes_code (code),
  INDEX referral_admin_codes_active (active, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS referral_milestones (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code_type ENUM('creator', 'admin') NOT NULL DEFAULT 'creator',
  uses_required INT UNSIGNED NOT NULL,
  label VARCHAR(160) NOT NULL,
  rewards JSON NOT NULL,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME(3) NOT NULL,
  INDEX referral_milestones_type_uses (code_type, uses_required)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
