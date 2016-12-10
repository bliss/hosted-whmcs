-- update from 7.0.0 to 7.0.2
ALTER TABLE `tblactivitylog` AUTO_INCREMENT = 30;
ALTER TABLE `tbltransientdata` AUTO_INCREMENT = 5;
DELETE FROM `tblconfiguration` WHERE setting='AdminForceSSL';
INSERT INTO `tblconfiguration` (setting, value) VALUES ('UpdaterLTS', '{"Active":["7.1","7.0","6.3"],"LTS":["6.2","6.1"]}');
UPDATE `tblconfiguration` SET value='7.0.2-release.1' WHERE setting='Version';
UPDATE `tblconfiguration` SET value='7.0.2-release.1' WHERE setting='UpdaterLatestStableVersion';
UPDATE `tblconfiguration` SET value='7.1.0-rc.1' WHERE setting='UpdaterLatestBetaVersion';
UPDATE `tblconfiguration` SET value='7.0.2-release.1' WHERE setting='UpdaterLatestVersion';
UPDATE `tblconfiguration` SET value='7.0.2-release.1' WHERE setting='UpdaterLatestSupportAndUpdatesVersion';
