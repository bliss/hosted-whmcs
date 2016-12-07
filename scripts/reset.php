<?php

$conf = '/var/opt/persistent/configuration.php';
if (!file_exists($conf)) die;
require_once $conf;


$options = getopt('', array('reset-password', 'reset-domain', 'reset-smtp'));
$reset_password = isset($options['reset-password']);
$reset_domain = isset($options['reset-domain']);
$reset_smtp = isset($options['reset-smtp']);

if (!$reset_password && !$reset_domain && !$reset_smtp) die;


function _hash($string) {
    if (function_exists("sha1")) {
        $hash = sha1($string);
    }
    else {
        $hash = md5($string);
    }

    $out = "";
    $c = 0;

    while ($c < strlen($hash)) {
        $out .= chr(hexdec($hash[$c] . $hash[$c + 1]));
        $c += 2;
    }

    return $out;
}

function _generate_iv() {
    global $cc_encryption_hash;

    srand((double)microtime() * 1000000);
    $iv = md5(strrev(substr($cc_encryption_hash, 13)) . substr($cc_encryption_hash, 0, 13));
    $iv .= rand(0, getrandmax());
    $iv .= serialize(array("key" => md5(md5($cc_encryption_hash)) . md5($cc_encryption_hash)));
    return _hash($iv);
}

function encrypt($string) {
    global $cc_encryption_hash;

    $key = md5(md5($cc_encryption_hash)) . md5($cc_encryption_hash);
    $hash_key = _hash($key);
    $hash_length = strlen($hash_key);
    $iv = _generate_iv();
    $out = "";
    $c = 0;

    while ($c < $hash_length) {
        $out .= chr(ord($iv[$c]) ^ ord($hash_key[$c]));
        ++$c;
    }

    $key = $iv;
    $c = 0;

    while ($c < strlen($string)) {
        if ($c != 0 && $c % $hash_length == 0) {
            $key = _hash($key . substr($string, $c - $hash_length, $hash_length));
        }

        $out .= chr(ord($key[$c % $hash_length]) ^ ord($string[$c]));
        ++$c;
    }

    $out = base64_encode($out);
    return $out;
}

try {
    $db = new PDO("mysql:host=${db_host};dbname=${db_name}", $db_username, $db_password);

    if ($reset_password) {
        $passwd = base64_encode(openssl_random_pseudo_bytes(18));
        echo $passwd;
        $st = $db->prepare("UPDATE tbladmins SET password=md5(?), passwordhash='' WHERE username='Admin'");
        $st->execute(array($passwd));
    }

    if ($reset_smtp) {
        $smtp_host = getenv('SMTP_HOST');
        $smtp_password = getenv('SMTP_PASSWORD');
        $smtp_port = getenv('SMTP_PORT');
        $smtp_protocol = getenv('SMTP_PROTOCOL');
        $from_email = getenv('FROM_EMAIL');

        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPUsername'");
        $st->execute(array($smtp_user));
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='MailType'");
        $st->execute(array('smtp'));

        if ($from_email) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='Email'");
            $st->execute(array($from_email));
        }
        if ($smtp_host) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPHost'");
            $st->execute(array($smtp_host));
        }
        if ($smtp_password) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPPassword'");
            $st->execute(array(encrypt($smtp_password)));
        }
        if ($smtp_port) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPPort'");
            $st->execute(array($smtp_port));
        }
        if ($smtp_protocol) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPSSL'");
            $st->execute(array($smtp_ssl));
        }
    }


    if ($reset_domain) {
        $domain = getenv('DOMAIN');
        $url = 'http://' . $domain;
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='Domain'");
        $st->execute(array($url));
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SystemURL'");
        $st->execute(array($url . '/'));
    }

} catch (PDOException $e) {
    die("Database error: " . $e->getMessage());
}
