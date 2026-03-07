CREATE TABLE IF NOT EXISTS `bans` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NULL,
  `license` VARCHAR(80) NULL,
  `discord` VARCHAR(80) NULL,
  `ip` VARCHAR(80) NULL,
  `reason` VARCHAR(255) NULL,
  `expire` BIGINT NULL DEFAULT 0,
  `bannedby` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_license` (`license`),
  KEY `idx_discord` (`discord`),
  KEY `idx_ip` (`ip`),
  KEY `idx_expire` (`expire`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_warns` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `senderIdentifier` VARCHAR(80) NULL,
  `targetIdentifier` VARCHAR(80) NULL,
  `reason` TEXT NULL,
  `warnId` VARCHAR(40) NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_warnid` (`warnId`),
  KEY `idx_targetIdentifier` (`targetIdentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `staff_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(64) NOT NULL,
  `action` VARCHAR(64) NOT NULL,
  `actor_src` INT NULL,
  `actor_name` VARCHAR(255) NULL,
  `actor_license` VARCHAR(80) NULL,
  `target_src` INT NULL,
  `target_name` VARCHAR(255) NULL,
  `target_license` VARCHAR(80) NULL,
  `message` TEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`),
  KEY `idx_action` (`action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `staff_reports` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `player_src` INT NULL,
  `player_name` VARCHAR(255) NULL,
  `player_license` VARCHAR(80) NULL,
  `player_citizenid` VARCHAR(80) NULL,
  `message` TEXT NULL,
  `status` VARCHAR(32) NOT NULL DEFAULT 'pendente',
  `priority` VARCHAR(32) NULL DEFAULT 'normal',
  `accepted_by_src` INT NULL,
  `accepted_by_name` VARCHAR(255) NULL,
  `accepted_at` TIMESTAMP NULL DEFAULT NULL,
  `closed_by_src` INT NULL,
  `closed_by_name` VARCHAR(255) NULL,
  `closed_at` TIMESTAMP NULL DEFAULT NULL,
  `response` TEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_status` (`status`),
  KEY `idx_player_license` (`player_license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `staff_report_messages` (
  `id` int NOT NULL AUTO_INCREMENT,
  `report_id` int NOT NULL,
  `sender_type` varchar(24) NOT NULL,
  `sender_src` int DEFAULT NULL,
  `sender_name` varchar(255) DEFAULT NULL,
  `sender_license` varchar(80) DEFAULT NULL,
  `message` text,
  `metadata` longtext,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_report_id` (`report_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
