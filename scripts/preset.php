<?php
$passwd = getenv('PASSWORD');
if (!$passwd) die;
$conf = '/var/opt/persistent/configuration.php';
if (!file_exists($conf)) die;
require_once $conf;

try {
    $db = new PDO("mysql:host=${db_host};dbname=${db_name}", $db_username, $db_password);
    $st = $db->prepare("UPDATE tbladmins SET password=md5(?) WHERE username='Admin' and passwordhash=''");
    $st->execute(array($passwd));
} catch (PDOException $e) {
    die("Database error: " . $e->getMessage());
}

