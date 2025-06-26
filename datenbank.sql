-- phpMyAdmin SQL Dump
-- version 5.1.1deb5ubuntu1
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Erstellungszeit: 26. Jun 2025 um 03:32
-- Server-Version: 10.6.22-MariaDB-0ubuntu0.22.04.1
-- PHP-Version: 8.1.2-1ubuntu2.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Datenbank: `s7354_datenbank`
--

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `account`
--

CREATE TABLE `account` (
  `id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `email` varchar(100) NOT NULL,
  `register_datum` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL,
  `ip_adresse` varchar(45) DEFAULT NULL,
  `admin_level` int(11) DEFAULT 0,
  `standard_skin` int(11) NOT NULL DEFAULT 0,
  `fraction_skin` int(11) NOT NULL DEFAULT 0,
  `banned` tinyint(1) DEFAULT 0,
  `ban_reason` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `account`
--

INSERT INTO `account` (`id`, `username`, `password`, `email`, `register_datum`, `last_login`, `ip_adresse`, `admin_level`, `standard_skin`, `fraction_skin`, `banned`, `ban_reason`) VALUES
(1, 'q', 'f1ab1fc67c6d3dfd1a40b0ce68a05af17d942167b61083bbea1882b1f6c87d00', 'q', '2025-02-24 06:00:20', NULL, NULL, 0, 0, 0, 0, NULL),
(6, 'keno', 'f1ab1fc67c6d3dfd1a40b0ce68a05af17d942167b61083bbea1882b1f6c87d00', 'qwe', '2025-02-24 06:15:13', '2025-06-26 03:23:06', '95.223.79.133', 1, 7, 296, 0, NULL),
(7, 'kenoZ', 'f1ab1fc67c6d3dfd1a40b0ce68a05af17d942167b61083bbea1882b1f6c87d00', 'keno@web.de', '2025-02-24 06:31:17', '2025-04-30 07:37:16', '95.223.79.133', 1, 0, 0, 0, NULL),
(13, 'kenoneu', 'fdc8cbadfc03a17abf72dfc905e1c4ba87d79a7d4d7441a5d27ba09e9ee5232e', 'koll@web.de', '2025-04-21 08:30:29', '2025-04-21 08:31:13', '95.223.79.133', 0, 0, 0, 0, NULL),
(14, 'NetSkyII', '079c00612d364c8ec8d7ffe5a7ab8f53f9c886b888eb9d580d190407da30fcbc', 'a@a.de', '2025-05-04 14:18:04', '2025-05-29 17:23:04', '95.90.220.149', 1, 0, 29, 0, NULL),
(15, 'kenotest', '9e69e7e29351ad837503c44a5971edebc9b7e6d8601c89c284b1b59bf37afa80', 'keno@webbb.de', '2025-05-15 03:52:17', '2025-05-15 03:52:20', '95.223.79.133', 0, 0, 0, 0, NULL),
(16, 'PUNDE', 'f1ab1fc67c6d3dfd1a40b0ce68a05af17d942167b61083bbea1882b1f6c87d00', 'udayanbira@gmail.com', '2025-05-19 12:19:13', NULL, '88.130.149.108', 0, 0, 0, 0, NULL),
(17, 'bira1', 'a5bdbc810d35116ad885e9c8ca490e5590cae4678e917419826ebb45a5a51afc', 'bira1@web.de', '2025-05-19 12:26:12', '2025-05-19 12:26:15', '95.223.79.133', 0, 0, 0, 0, NULL),
(18, '12345', '5994471abb01112afcc18159f6cc74b4f511b99806da59b3caf5a9c173cacfc5', '12345@web.de', '2025-05-19 12:27:31', '2025-05-19 18:50:40', '88.130.149.108', 0, 0, 274, 0, NULL),
(19, 'rvtyy', '2f2b7e7af790d7c63fab4022e35a6f6456b19161469a622747feeaf370cc005c', 'youngrvty@gmail.com', '2025-05-29 13:03:50', '2025-05-30 12:45:15', '213.142.97.238', 1, 0, 126, 0, NULL),
(20, 'skender', 'fdc8cbadfc03a17abf72dfc905e1c4ba87d79a7d4d7441a5d27ba09e9ee5232e', 'skender@web.de', '2025-06-04 11:05:40', '2025-06-04 11:05:44', '95.223.79.133', 0, 0, 0, 0, NULL);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `active_bank_robberies`
--

CREATE TABLE `active_bank_robberies` (
  `bank_id` int(11) NOT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 0,
  `end_tick_time` bigint(20) DEFAULT NULL,
  `participants` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `active_bank_robberies`
--

INSERT INTO `active_bank_robberies` (`bank_id`, `is_active`, `end_tick_time`, `participants`) VALUES
(1, 0, 0, NULL);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `bank_cooldowns`
--

CREATE TABLE `bank_cooldowns` (
  `bank_id` int(11) NOT NULL,
  `cooldown_end_tick_time` bigint(20) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `bank_cooldowns`
--

INSERT INTO `bank_cooldowns` (`bank_id`, `cooldown_end_tick_time`) VALUES
(1, 26010869);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `faction_treasuries`
--

CREATE TABLE `faction_treasuries` (
  `fraction_id` int(11) NOT NULL,
  `balance` bigint(20) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `faction_treasuries`
--

INSERT INTO `faction_treasuries` (`fraction_id`, `balance`) VALUES
(7, 288300);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `fraction_members`
--

CREATE TABLE `fraction_members` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `fraction_id` int(11) NOT NULL,
  `rank_level` int(11) NOT NULL DEFAULT 1,
  `on_duty` tinyint(1) NOT NULL DEFAULT 0 COMMENT '0 = Off-Duty, 1 = On-Duty'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `fraction_members`
--

INSERT INTO `fraction_members` (`id`, `account_id`, `fraction_id`, `rank_level`, `on_duty`) VALUES
(267, 10, 4, 5, 0),
(361, 18, 3, 5, 1),
(420, 19, 4, 5, 0),
(445, 14, 1, 5, 0),
(479, 6, 5, 5, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `handy_messages`
--

CREATE TABLE `handy_messages` (
  `message_id` int(11) NOT NULL,
  `sender_acc_id` int(11) NOT NULL,
  `receiver_acc_id` int(11) NOT NULL,
  `message_text` varchar(255) NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_read` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `handy_messages`
--

INSERT INTO `handy_messages` (`message_id`, `sender_acc_id`, `receiver_acc_id`, `message_text`, `timestamp`, `is_read`) VALUES
(49, 6, 14, 'Moin', '2025-05-21 17:54:10', 1),
(50, 14, 6, 'hello', '2025-05-21 17:54:15', 1),
(51, 6, 14, 'was geht ab', '2025-05-21 17:54:20', 1),
(52, 6, 14, 'homo', '2025-05-25 02:31:01', 1),
(53, 6, 14, 'Moin', '2025-05-27 16:34:11', 1),
(54, 14, 6, 'nice', '2025-05-27 16:34:36', 1),
(55, 6, 14, 'x', '2025-05-28 08:50:51', 0),
(56, 19, 6, 'du wixxer', '2025-05-29 13:18:40', 1),
(57, 6, 19, 'ya manyka', '2025-05-29 13:18:43', 1),
(58, 6, 19, 'manyak', '2025-05-29 13:18:45', 1),
(59, 6, 19, 'ya ars', '2025-05-29 13:18:49', 1),
(60, 19, 6, 'rede antständig', '2025-05-29 13:18:50', 1),
(61, 19, 6, 'ya kelb', '2025-05-29 13:18:51', 1),
(62, 19, 6, 'ya ars', '2025-05-29 13:18:52', 1),
(63, 6, 19, 'ya wisikh', '2025-05-29 13:18:52', 1),
(64, 6, 19, 'ya kelb', '2025-05-29 13:18:53', 1),
(65, 19, 6, 'ya nitchis', '2025-05-29 13:18:54', 1),
(66, 6, 19, 'ya jahesh', '2025-05-29 13:18:56', 1);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `houses`
--

CREATE TABLE `houses` (
  `id` int(11) NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `posZ` float NOT NULL,
  `price` int(11) NOT NULL DEFAULT 10000,
  `owner_account_id` int(11) DEFAULT NULL,
  `locked` tinyint(1) NOT NULL DEFAULT 1,
  `interior_id` int(11) DEFAULT 0,
  `interior_posX` float DEFAULT NULL,
  `interior_posY` float DEFAULT NULL,
  `interior_posZ` float DEFAULT NULL,
  `creation_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `houses`
--

INSERT INTO `houses` (`id`, `posX`, `posY`, `posZ`, `price`, `owner_account_id`, `locked`, `interior_id`, `interior_posX`, `interior_posY`, `interior_posZ`, `creation_date`, `last_update`) VALUES
(1, -1.54883, 74.5059, 3.11719, 75000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-29 08:53:29', '2025-04-30 05:12:33'),
(2, 2.50293, 73.1211, 3.11719, 75000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-29 09:02:59', '2025-04-30 05:13:17'),
(3, -9.84375, 54.7861, 3.11719, 75000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-29 09:08:53', '2025-04-30 05:13:19'),
(4, -2127.99, 187.72, 37.1041, 500000, 19, 1, 5, NULL, NULL, NULL, '2025-04-30 05:02:47', '2025-05-29 13:22:00'),
(5, -2128.25, 162.903, 37.1041, 500000, 14, 1, 5, NULL, NULL, NULL, '2025-04-30 05:06:33', '2025-05-04 14:23:03'),
(6, -2126.47, 234.298, 35.7114, 500000, NULL, 1, 5, NULL, NULL, NULL, '2025-04-30 05:07:18', '2025-04-30 05:13:24'),
(7, -2127, 265.041, 35.7826, 500000, NULL, 1, 5, NULL, NULL, NULL, '2025-04-30 05:08:11', '2025-04-30 05:13:27'),
(8, -2127.1, 295.718, 35.4674, 500000, NULL, 1, 5, NULL, NULL, NULL, '2025-04-30 05:09:01', '2025-04-30 05:13:29'),
(9, -2093.09, 227.784, 35.5674, 500000, NULL, 1, 5, NULL, NULL, NULL, '2025-04-30 05:09:58', '2025-04-30 05:09:58'),
(10, -2122.03, 128.565, 37.1041, 500000, 6, 1, 5, NULL, NULL, NULL, '2025-04-30 05:10:26', '2025-06-05 17:24:44'),
(11, -2088.89, 94.9832, 35.6029, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:10:46', '2025-06-05 17:24:19'),
(12, -2088.89, 84.9541, 35.6029, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:10:59', '2025-04-30 05:12:04'),
(13, -2088.89, 74.9912, 35.6029, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:11:17', '2025-04-30 05:11:17'),
(14, -2027.92, -40.8799, 38.8047, 750000, NULL, 1, 9, NULL, NULL, NULL, '2025-04-30 05:15:57', '2025-04-30 05:15:57'),
(15, -2062.53, -60.6289, 35.3203, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:16:34', '2025-04-30 05:16:34'),
(16, -2050.1, -60.6289, 35.3138, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:16:46', '2025-04-30 05:16:46'),
(17, -2109.82, -60.6094, 35.3203, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:17:10', '2025-04-30 05:17:10'),
(18, -2122.23, -60.6084, 35.3203, 250000, NULL, 1, 4, NULL, NULL, NULL, '2025-04-30 05:17:24', '2025-04-30 05:17:24'),
(19, -2655.46, 986.634, 64.9913, 2000000, NULL, 1, 5, NULL, NULL, NULL, '2025-06-05 17:03:59', '2025-06-05 17:03:59');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `items`
--

CREATE TABLE `items` (
  `item_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `type` varchar(50) NOT NULL DEFAULT 'general',
  `max_stack` int(11) NOT NULL DEFAULT 1,
  `weight` float DEFAULT 0,
  `data` text DEFAULT NULL,
  `buy_price` int(11) DEFAULT NULL,
  `sell_price` int(11) DEFAULT NULL,
  `image_path` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `items`
--

INSERT INTO `items` (`item_id`, `name`, `description`, `type`, `max_stack`, `weight`, `data`, `buy_price`, `sell_price`, `image_path`) VALUES
(1, 'Verbandskasten', 'Stellt etwas Gesundheit wieder her.', 'usable', 10, 0.5, '{\"heal_amount\": 30}', 150, 50, 'user/client/images/items/item_1.png'),
(2, 'Wasserflasche', 'Löscht den Durst.', 'usable', 5, 0.3, '{\"thirst_restore\": 40}', 50, 10, 'user/client/images/items/item_2.png'),
(3, 'Dietrich', 'Zum Knacken von Schlössern.', 'tool', 5, 0.2, NULL, 500, 100, 'user/client/images/items/item_3.png'),
(4, 'Pistolenmunition', '9mm Munition.', 'ammo', 100, 0.01, '{\"weapon_type\": 22}', 10, 2, 'user/client/images/items/item_4.png'),
(5, 'Colt 1911', 'Standard Pistole.', 'weapon', 1, 1.5, '{\"weapon_id\": 22}', 2500, 800, 'user/client/images/items/item_5.png'),
(6, 'Geldtasche (Leer)', 'Eine leere Tasche für Diebesgut.', 'container', 1, 0.1, NULL, NULL, 5, 'user/client/images/items/item_6.png'),
(7, 'Geldtasche (Voll)', 'Enthält Diebesgut.', 'quest', 1, 2, NULL, NULL, NULL, 'user/client/images/items/item_7.png'),
(8, 'Bohrer', 'Ein schwerer Bohrer zum Öffnen von Tresoren.', 'tool', 1, 5, NULL, 15000, 500, 'user/client/images/items/item_8.png'),
(9, 'Sprengladung C4', 'Industrieller Sprengstoff. Vorsicht!', 'tool', 1, 2, NULL, 25000, 1000, 'user/client/images/items/item_9.png'),
(10, 'Goldbarren', 'Ein schwerer Goldbarren. Wertvoll.', 'loot', 5, 8, NULL, NULL, 35000, 'user/client/images/items/item_10.png'),
(11, 'Laptop', 'Ein tragbarer Computer, nützlich für Hacking-Aufgaben.', 'tool', 1, 2, NULL, 7500, 2500, 'user/client/images/items/laptop.png'),
(12, 'Brechstange', 'Eine robuste Brechstange zum Aufhebeln von Türen und Kisten.', 'tool', 1, 2.5, NULL, 750, 150, 'user/client/images/items/item_12.png'),
(13, 'Silberbarren', 'Ein glänzender Barren aus reinem Silber.', 'loot', 10, 5, NULL, NULL, 15000, 'user/client/images/items/item_13.png'),
(14, 'Diamant', 'Ein makelloser, wertvoller Diamant.', 'loot', 5, 0.1, NULL, NULL, 75000, 'user/client/images/items/item_14.png'),
(15, 'Golden Chip', 'Ein seltener, goldener Casino-Chip.', 'collectible', 20, 0.05, NULL, NULL, 5000, 'user/client/images/items/item_15.png'),
(16, 'Schmuck', 'Eine Sammlung wertvoller Schmuckstücke.', 'loot', 1, 0.5, '{\"pieces\": [\"Kette\", \"Ring\", \"Armband\"]}', NULL, 40000, 'user/client/images/items/item_16.png'),
(17, 'Personalausweis', 'Offizielles Identitätsdokument.', 'document', 1, 0.1, NULL, NULL, 0, 'user/client/images/items/id.png'),
(18, 'Führerschein', 'Offizieller Führerschein', 'document', 1, 0.1, NULL, NULL, 0, 'user/client/images/items/license.png'),
(19, 'Handy', 'Ein modernes Smartphone.', 'usable', 1, 0.2, NULL, 2500, 500, 'user/client/images/items/handy.png'),
(20, 'Cannabis Seed', 'Samen zum Anpflanzen von Cannabis.', 'seed', 50, 0.01, NULL, 50, 10, 'user/client/images/items/cannabis_seed.png'),
(21, 'Cannabis', 'Frisches Cannabis', 'raw_drug', 100, 0.05, NULL, NULL, 150, 'user/client/images/items/raw_cannabis.png'),
(22, 'Cocain Seed', 'Setzling zum Anpflanzen von Koka.', 'seed', 50, 0.01, NULL, 70, 15, 'user/client/images/items/koka_seedling.png'),
(23, 'Cocain', 'Frisches Cocain', 'raw_drug', 100, 0.04, NULL, NULL, 200, 'user/client/images/items/raw_koka.png');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `jobs`
--

CREATE TABLE `jobs` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `job_name` varchar(100) NOT NULL,
  `job_rank` int(11) DEFAULT 1,
  `last_worked` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `licenses`
--

CREATE TABLE `licenses` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `motorcycle` tinyint(1) DEFAULT 0,
  `car` tinyint(1) DEFAULT 0,
  `truck` tinyint(1) DEFAULT 0,
  `plane` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `money`
--

CREATE TABLE `money` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `money` int(11) DEFAULT 0,
  `bank_money` int(11) NOT NULL DEFAULT 0 COMMENT 'Guthaben auf dem Bankkonto'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `money`
--

INSERT INTO `money` (`id`, `account_id`, `money`, `bank_money`) VALUES
(10, 6, 2554, 25156130),
(14, 13, 0, 0),
(15, 7, 500, 0),
(16, 14, 406491, 5000000),
(17, 15, 0, 0),
(18, 16, 0, 0),
(19, 17, 0, 0),
(20, 18, 0, 0),
(21, 19, 1135383, 54000000),
(22, 20, 0, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `player_inventory`
--

CREATE TABLE `player_inventory` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `slot` int(11) NOT NULL,
  `metadata` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `player_inventory`
--

INSERT INTO `player_inventory` (`id`, `account_id`, `item_id`, `quantity`, `slot`, `metadata`) VALUES
(14772, 14, 8, 1, 1, NULL),
(14773, 14, 18, 1, 2, 'licenses:bike,car|name:NetSky|issuedDate:21.05.2025'),
(14774, 14, 11, 1, 3, NULL),
(14775, 14, 3, 5, 4, NULL),
(14776, 14, 9, 1, 5, NULL),
(14777, 14, 13, 1, 6, NULL),
(14778, 14, 19, 1, 7, NULL),
(14779, 14, 9, 1, 9, NULL),
(14780, 14, 9, 1, 10, NULL),
(14781, 14, 9, 1, 11, NULL),
(14782, 14, 17, 1, 12, 'issued:17.05.2025|name:NetSky|skin:294|serialNumber:SA-88088-14174747|accountId:14'),
(14783, 14, 8, 1, 13, NULL),
(14784, 14, 8, 1, 14, NULL),
(14785, 14, 8, 1, 15, NULL),
(14934, 19, 17, 1, 1, 'issued:29.05.2025|name:rvty12|skin:0|serialNumber:SA-35595-19174852|accountId:19'),
(14935, 19, 18, 1, 2, 'licenses:car|name:rvty12|issuedDate:29.05.2025'),
(14936, 19, 19, 1, 3, NULL),
(18162, 6, 3, 1, 1, NULL),
(18163, 6, 20, 50, 2, NULL),
(18164, 6, 22, 45, 3, NULL),
(18165, 6, 20, 8, 4, NULL),
(18166, 6, 21, 7, 5, NULL),
(18167, 6, 18, 1, 11, 'licenses:car|name:keno|issuedDate:04.06.2025'),
(18168, 6, 17, 1, 12, 'issued:31.05.2025|name:keno|skin:274|serialNumber:SA-48696-61748693|accountId:6');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `player_job_skills`
--

CREATE TABLE `player_job_skills` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `job_name` varchar(50) NOT NULL,
  `skill_level` int(11) NOT NULL DEFAULT 1,
  `experience` int(11) NOT NULL DEFAULT 0,
  `jobs_completed_total` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `player_job_skills`
--

INSERT INTO `player_job_skills` (`id`, `account_id`, `job_name`, `skill_level`, `experience`, `jobs_completed_total`) VALUES
(1, 6, 'muellfahrer', 2, 0, 19),
(9, 6, 'lkwfahrer', 1, 0, 7);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `player_kill_stats`
--

CREATE TABLE `player_kill_stats` (
  `account_id` int(11) NOT NULL,
  `total_kills` int(11) NOT NULL DEFAULT 0,
  `reputation` int(11) NOT NULL DEFAULT 0,
  `current_title` varchar(50) DEFAULT 'Beginner',
  `last_kill_date` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `player_kill_stats`
--

INSERT INTO `player_kill_stats` (`account_id`, `total_kills`, `reputation`, `current_title`, `last_kill_date`) VALUES
(6, 19, -20, 'Thug Life', '2025-05-30 12:48:13'),
(14, 0, 0, 'Beginner', '2025-05-29 16:52:33'),
(19, 6, 12, 'Constable', '2025-05-30 14:08:38');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `player_licenses`
--

CREATE TABLE `player_licenses` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `license_type` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'pending_theory',
  `issue_date` date DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `points` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Daten für Tabelle `player_licenses`
--

INSERT INTO `player_licenses` (`id`, `account_id`, `license_type`, `status`, `issue_date`, `expiry_date`, `points`) VALUES
(59, 6, 'car', 'active', '2025-06-04', NULL, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `player_spawnpoints`
--

CREATE TABLE `player_spawnpoints` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `posZ` float NOT NULL,
  `rotation` float NOT NULL,
  `dimension` int(11) DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `selected` tinyint(1) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `playtime`
--

CREATE TABLE `playtime` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `total_minutes` int(11) DEFAULT 0,
  `last_session_start` timestamp NULL DEFAULT NULL,
  `last_session_end` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `playtime`
--

INSERT INTO `playtime` (`id`, `account_id`, `total_minutes`, `last_session_start`, `last_session_end`) VALUES
(4481, 13, 1, '2025-04-21 08:31:19', '2025-04-21 08:31:19'),
(4650, 6, 21670, '2025-04-23 02:44:54', '2025-06-26 03:31:36'),
(5685, 7, 5, NULL, '2025-04-30 07:42:23'),
(5874, 14, 896, '2025-05-04 14:18:04', '2025-05-29 19:33:38'),
(10281, 15, 1, '2025-05-15 03:52:17', '2025-05-15 03:53:22'),
(12676, 16, 0, '2025-05-19 12:19:13', '2025-05-19 12:19:13'),
(12685, 17, 0, '2025-05-19 12:26:12', '2025-05-19 12:26:12'),
(12687, 18, 301, '2025-05-19 12:27:31', '2025-05-19 21:20:37'),
(19294, 19, 327, '2025-05-29 13:03:50', '2025-05-30 15:17:33'),
(22241, 20, 0, '2025-06-04 11:05:40', '2025-06-04 11:05:40');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `positions`
--

CREATE TABLE `positions` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `posZ` float NOT NULL,
  `rotation` float NOT NULL,
  `dimension` int(11) DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `positions`
--

INSERT INTO `positions` (`id`, `account_id`, `posX`, `posY`, `posZ`, `rotation`, `dimension`, `interior`, `last_update`) VALUES
(16, 6, -2395.21, -4.4668, 35.3125, 170.958, 0, 0, '2025-06-13 04:19:13'),
(141, 7, -2115.07, 126.404, 36.1077, 84.2142, 0, 0, '2025-04-30 07:42:23'),
(157, 14, -497.193, -530.161, 25.5178, 303.757, 0, 0, '2025-05-29 19:33:38'),
(772, 15, -0.541992, 0.404297, 3.11719, 65.1746, 0, 0, '2025-05-15 03:53:22'),
(1167, 17, 2.23633, 10.1309, 3.10965, 23.1842, 0, 0, '2025-05-19 12:26:23'),
(1168, 18, -2917.5, 15.0732, 2.21162, 326.813, 0, 0, '2025-05-19 21:20:37'),
(2005, 19, -2040.08, 153.977, 34.9332, 277.307, 0, 0, '2025-05-30 15:17:33'),
(2124, 20, 0, 0, 0, 180, 0, 0, '2025-06-04 11:05:44');

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `territories`
--

CREATE TABLE `territories` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `sizeX` float NOT NULL,
  `sizeY` float NOT NULL,
  `owner_faction_id` int(11) DEFAULT 0 COMMENT '0 für neutral/frei'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `territories`
--

INSERT INTO `territories` (`id`, `name`, `posX`, `posY`, `sizeX`, `sizeY`, `owner_faction_id`) VALUES
(1, 'Grove Street', 2487, -1667, 150, 150, 5),
(2, 'Tennis Sportplatz', -2752.02, -251.692, 150, 150, 5),
(3, 'SF Sea', -2894, 462.888, 200, 200, 0),
(5, 'LV Parlament', 1087, 1073, 200, 200, 0),
(6, 'LV Storm-Village', 1484, 2774, 300, 300, 0),
(7, 'SF Car-Park', -2633.42, 1386.53, 300, 300, 0),
(8, 'League of Cows', 221.815, -148.646, 228, 137, 0),
(9, 'King Samuil', -24.3069, -2508.48, 100, 100, 0),
(10, 'Los Santos 7th', 876.688, -1232.36, 161, 172, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `vehicles`
--

CREATE TABLE `vehicles` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `model` int(11) NOT NULL,
  `posX` float DEFAULT 0,
  `posY` float DEFAULT 0,
  `posZ` float DEFAULT 0,
  `rotation` float DEFAULT 0,
  `dimension` int(11) DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `fuel` decimal(5,2) NOT NULL DEFAULT 100.00,
  `locked` tinyint(1) DEFAULT 0,
  `color1` int(11) DEFAULT 0,
  `color2` int(11) DEFAULT 0,
  `color3` int(11) DEFAULT 0,
  `color4` int(11) DEFAULT 0,
  `rgb_r1` int(3) DEFAULT NULL,
  `rgb_g1` int(3) DEFAULT NULL,
  `rgb_b1` int(3) DEFAULT NULL,
  `rgb_r2` int(3) DEFAULT NULL,
  `rgb_g2` int(3) DEFAULT NULL,
  `rgb_b2` int(3) DEFAULT NULL,
  `rgb_r3` int(3) DEFAULT NULL,
  `rgb_g3` int(3) DEFAULT NULL,
  `rgb_b3` int(3) DEFAULT NULL,
  `rgb_r4` int(3) DEFAULT NULL,
  `rgb_g4` int(3) DEFAULT NULL,
  `rgb_b4` int(3) DEFAULT NULL,
  `tune1` int(11) DEFAULT NULL,
  `tune2` int(11) DEFAULT NULL,
  `tune3` int(11) DEFAULT NULL,
  `tune4` int(11) DEFAULT NULL,
  `tune5` int(11) DEFAULT NULL,
  `tune6` int(11) DEFAULT NULL,
  `tune7` int(11) DEFAULT NULL,
  `tune8` int(11) DEFAULT NULL,
  `tune9` int(11) DEFAULT NULL,
  `tune10` int(11) DEFAULT NULL,
  `health` float(10,2) NOT NULL DEFAULT 1000.00,
  `engine` tinyint(1) DEFAULT 1,
  `odometer` float NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `vehicles`
--

INSERT INTO `vehicles` (`id`, `account_id`, `model`, `posX`, `posY`, `posZ`, `rotation`, `dimension`, `interior`, `fuel`, `locked`, `color1`, `color2`, `color3`, `color4`, `rgb_r1`, `rgb_g1`, `rgb_b1`, `rgb_r2`, `rgb_g2`, `rgb_b2`, `rgb_r3`, `rgb_g3`, `rgb_b3`, `rgb_r4`, `rgb_g4`, `rgb_b4`, `tune1`, `tune2`, `tune3`, `tune4`, `tune5`, `tune6`, `tune7`, `tune8`, `tune9`, `tune10`, `health`, `engine`, `odometer`) VALUES
(5, 6, 400, -1999.77, 139.509, 28.2432, 356.083, 0, 0, '75.51', 0, 1, 65, 6, 6, 255, 255, 255, 143, 127, 0, 197, 180, 0, 255, 180, 0, 2, 2, 1077, 0, 0, 0, 0, 0, 0, 0, 1000.00, 1, 4651.42),
(6, 6, 402, -2030, 179.001, 28.6368, 180.033, 0, 0, '98.65', 0, 65, 118, 118, 86, 134, 213, 0, 99, 255, 255, 99, 177, 250, 0, 210, 0, 3, 1, 1078, 0, 0, 0, 0, 0, 0, 0, 1000.00, 1, 1.44019),
(7, 6, 411, -1264.09, 223.155, 13.8737, 314.857, 0, 0, '93.31', 0, 6, 86, 86, 86, 230, 122, 15, 83, 122, 15, 83, 122, 15, 83, 122, 15, 3, 3, 1080, 0, 0, 0, 0, 0, 0, 0, 1000.00, 1, 74.3522),
(8, 6, 451, -2030, 178.989, 28.4603, 180.027, 0, 0, '100.00', 0, 22, 22, 22, 22, 96, 0, 93, 96, 0, 93, 96, 0, 93, 96, 0, 93, 3, 3, 1077, 0, 0, 0, 0, 0, 0, 0, 1000.00, 1, 42.9637),
(13, 14, 411, -2706.08, 258.275, 3.90675, 359.758, 0, 0, '81.70', 0, 0, 79, 79, 79, 10, 10, 10, 0, 0, 200, 0, 0, 200, 0, 0, 200, 3, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 814.50, 1, 37.5574);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `vehicle_positions`
--

CREATE TABLE `vehicle_positions` (
  `id` int(11) NOT NULL,
  `vehicle_id` int(11) NOT NULL,
  `posX` float NOT NULL,
  `posY` float NOT NULL,
  `posZ` float NOT NULL,
  `rotation` float NOT NULL,
  `dimension` int(11) DEFAULT 0,
  `interior` int(11) DEFAULT 0,
  `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `wanteds`
--

CREATE TABLE `wanteds` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `wanted_level` int(11) NOT NULL DEFAULT 0,
  `prisontime` int(11) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `wanteds`
--

INSERT INTO `wanteds` (`id`, `account_id`, `wanted_level`, `prisontime`) VALUES
(1, 6, 0, 0),
(2, 10, 35, 380),
(4, 13, 0, 0),
(75, 7, 0, 0),
(81, 14, 0, 0),
(1651, 15, 0, 0),
(1905, 16, 0, 0),
(1906, 17, 0, 0),
(1907, 18, 0, 0),
(2198, 19, 0, 0),
(2837, 20, 0, 0);

-- --------------------------------------------------------

--
-- Tabellenstruktur für Tabelle `weapons`
--

CREATE TABLE `weapons` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `weapon_slot1` int(11) DEFAULT NULL,
  `ammo_slot1` int(11) DEFAULT 0,
  `weapon_slot2` int(11) DEFAULT NULL,
  `ammo_slot2` int(11) DEFAULT 0,
  `weapon_slot3` int(11) DEFAULT NULL,
  `ammo_slot3` int(11) DEFAULT 0,
  `weapon_slot4` int(11) DEFAULT NULL,
  `ammo_slot4` int(11) DEFAULT 0,
  `weapon_slot5` int(11) DEFAULT NULL,
  `ammo_slot5` int(11) DEFAULT 0,
  `weapon_slot6` int(11) DEFAULT NULL,
  `ammo_slot6` int(11) DEFAULT 0,
  `weapon_slot7` int(11) DEFAULT NULL,
  `ammo_slot7` int(11) DEFAULT 0,
  `weapon_slot8` int(11) DEFAULT NULL,
  `ammo_slot8` int(11) DEFAULT 0,
  `weapon_slot9` int(11) DEFAULT NULL,
  `ammo_slot9` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Daten für Tabelle `weapons`
--

INSERT INTO `weapons` (`id`, `account_id`, `weapon_slot1`, `ammo_slot1`, `weapon_slot2`, `ammo_slot2`, `weapon_slot3`, `ammo_slot3`, `weapon_slot4`, `ammo_slot4`, `weapon_slot5`, `ammo_slot5`, `weapon_slot6`, `ammo_slot6`, `weapon_slot7`, `ammo_slot7`, `weapon_slot8`, `ammo_slot8`, `weapon_slot9`, `ammo_slot9`) VALUES
(7, 6, 4, 1, 24, 35, 25, 30, 32, 120, 30, 60, 34, 7, 16, 2, NULL, 0, NULL, 0),
(558, 14, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0),
(702, 19, 38, 1669, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0, NULL, 0);

--
-- Indizes der exportierten Tabellen
--

--
-- Indizes für die Tabelle `account`
--
ALTER TABLE `account`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `username` (`username`);

--
-- Indizes für die Tabelle `active_bank_robberies`
--
ALTER TABLE `active_bank_robberies`
  ADD PRIMARY KEY (`bank_id`);

--
-- Indizes für die Tabelle `bank_cooldowns`
--
ALTER TABLE `bank_cooldowns`
  ADD PRIMARY KEY (`bank_id`);

--
-- Indizes für die Tabelle `faction_treasuries`
--
ALTER TABLE `faction_treasuries`
  ADD PRIMARY KEY (`fraction_id`);

--
-- Indizes für die Tabelle `fraction_members`
--
ALTER TABLE `fraction_members`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`),
  ADD KEY `idx_fraction_id` (`fraction_id`);

--
-- Indizes für die Tabelle `handy_messages`
--
ALTER TABLE `handy_messages`
  ADD PRIMARY KEY (`message_id`),
  ADD KEY `idx_sender` (`sender_acc_id`),
  ADD KEY `idx_receiver` (`receiver_acc_id`);

--
-- Indizes für die Tabelle `houses`
--
ALTER TABLE `houses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_owner_account_id` (`owner_account_id`);

--
-- Indizes für die Tabelle `items`
--
ALTER TABLE `items`
  ADD PRIMARY KEY (`item_id`),
  ADD KEY `idx_item_name` (`name`),
  ADD KEY `idx_item_type` (`type`);

--
-- Indizes für die Tabelle `jobs`
--
ALTER TABLE `jobs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`);

--
-- Indizes für die Tabelle `licenses`
--
ALTER TABLE `licenses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`);

--
-- Indizes für die Tabelle `money`
--
ALTER TABLE `money`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_account_id` (`account_id`);

--
-- Indizes für die Tabelle `player_inventory`
--
ALTER TABLE `player_inventory`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_player_slot` (`account_id`,`slot`),
  ADD UNIQUE KEY `unique_account_slot` (`account_id`,`slot`),
  ADD KEY `idx_inventory_account_id` (`account_id`),
  ADD KEY `idx_inventory_item_id` (`item_id`);

--
-- Indizes für die Tabelle `player_job_skills`
--
ALTER TABLE `player_job_skills`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `account_job` (`account_id`,`job_name`);

--
-- Indizes für die Tabelle `player_kill_stats`
--
ALTER TABLE `player_kill_stats`
  ADD PRIMARY KEY (`account_id`);

--
-- Indizes für die Tabelle `player_licenses`
--
ALTER TABLE `player_licenses`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `account_license_type` (`account_id`,`license_type`);

--
-- Indizes für die Tabelle `player_spawnpoints`
--
ALTER TABLE `player_spawnpoints`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`);

--
-- Indizes für die Tabelle `playtime`
--
ALTER TABLE `playtime`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_account_id` (`account_id`);

--
-- Indizes für die Tabelle `positions`
--
ALTER TABLE `positions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_account_id` (`account_id`);

--
-- Indizes für die Tabelle `territories`
--
ALTER TABLE `territories`
  ADD PRIMARY KEY (`id`);

--
-- Indizes für die Tabelle `vehicles`
--
ALTER TABLE `vehicles`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`),
  ADD KEY `idx_model` (`model`);

--
-- Indizes für die Tabelle `vehicle_positions`
--
ALTER TABLE `vehicle_positions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_vehicle_id` (`vehicle_id`);

--
-- Indizes für die Tabelle `wanteds`
--
ALTER TABLE `wanteds`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_account_id` (`account_id`);

--
-- Indizes für die Tabelle `weapons`
--
ALTER TABLE `weapons`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `account_id` (`account_id`),
  ADD KEY `idx_account_id` (`account_id`);

--
-- AUTO_INCREMENT für exportierte Tabellen
--

--
-- AUTO_INCREMENT für Tabelle `account`
--
ALTER TABLE `account`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT für Tabelle `fraction_members`
--
ALTER TABLE `fraction_members`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=480;

--
-- AUTO_INCREMENT für Tabelle `handy_messages`
--
ALTER TABLE `handy_messages`
  MODIFY `message_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=67;

--
-- AUTO_INCREMENT für Tabelle `houses`
--
ALTER TABLE `houses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT für Tabelle `items`
--
ALTER TABLE `items`
  MODIFY `item_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT für Tabelle `jobs`
--
ALTER TABLE `jobs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `licenses`
--
ALTER TABLE `licenses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `money`
--
ALTER TABLE `money`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT für Tabelle `player_inventory`
--
ALTER TABLE `player_inventory`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18169;

--
-- AUTO_INCREMENT für Tabelle `player_job_skills`
--
ALTER TABLE `player_job_skills`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT für Tabelle `player_licenses`
--
ALTER TABLE `player_licenses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=60;

--
-- AUTO_INCREMENT für Tabelle `player_spawnpoints`
--
ALTER TABLE `player_spawnpoints`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `playtime`
--
ALTER TABLE `playtime`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24456;

--
-- AUTO_INCREMENT für Tabelle `positions`
--
ALTER TABLE `positions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2293;

--
-- AUTO_INCREMENT für Tabelle `territories`
--
ALTER TABLE `territories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT für Tabelle `vehicles`
--
ALTER TABLE `vehicles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT für Tabelle `vehicle_positions`
--
ALTER TABLE `vehicle_positions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT für Tabelle `wanteds`
--
ALTER TABLE `wanteds`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2838;

--
-- AUTO_INCREMENT für Tabelle `weapons`
--
ALTER TABLE `weapons`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=858;

--
-- Constraints der exportierten Tabellen
--

--
-- Constraints der Tabelle `handy_messages`
--
ALTER TABLE `handy_messages`
  ADD CONSTRAINT `fk_msg_receiver` FOREIGN KEY (`receiver_acc_id`) REFERENCES `account` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_msg_sender` FOREIGN KEY (`sender_acc_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `houses`
--
ALTER TABLE `houses`
  ADD CONSTRAINT `fk_house_owner` FOREIGN KEY (`owner_account_id`) REFERENCES `account` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints der Tabelle `jobs`
--
ALTER TABLE `jobs`
  ADD CONSTRAINT `jobs_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `licenses`
--
ALTER TABLE `licenses`
  ADD CONSTRAINT `licenses_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `money`
--
ALTER TABLE `money`
  ADD CONSTRAINT `money_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `player_inventory`
--
ALTER TABLE `player_inventory`
  ADD CONSTRAINT `fk_inventory_account` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_inventory_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints der Tabelle `player_job_skills`
--
ALTER TABLE `player_job_skills`
  ADD CONSTRAINT `player_job_skills_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `player_kill_stats`
--
ALTER TABLE `player_kill_stats`
  ADD CONSTRAINT `fk_player_kill_stats_account` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints der Tabelle `player_licenses`
--
ALTER TABLE `player_licenses`
  ADD CONSTRAINT `player_licenses_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints der Tabelle `player_spawnpoints`
--
ALTER TABLE `player_spawnpoints`
  ADD CONSTRAINT `player_spawnpoints_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `playtime`
--
ALTER TABLE `playtime`
  ADD CONSTRAINT `playtime_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `positions`
--
ALTER TABLE `positions`
  ADD CONSTRAINT `positions_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `vehicles`
--
ALTER TABLE `vehicles`
  ADD CONSTRAINT `vehicles_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `vehicle_positions`
--
ALTER TABLE `vehicle_positions`
  ADD CONSTRAINT `vehicle_positions_ibfk_1` FOREIGN KEY (`vehicle_id`) REFERENCES `vehicles` (`id`) ON DELETE CASCADE;

--
-- Constraints der Tabelle `weapons`
--
ALTER TABLE `weapons`
  ADD CONSTRAINT `weapons_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
