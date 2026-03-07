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
