-- Sergei Bus Job Database Table
-- This table stores player XP for the bus driving job

CREATE TABLE IF NOT EXISTS `sergei_bus_xp` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(50) NOT NULL,
  `bus_xp` int(11) NOT NULL DEFAULT 0,
  `jobs_completed` int(11) NOT NULL DEFAULT 0,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;