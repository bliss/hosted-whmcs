<?php
$passwd = getenv('PASSWORD');
$smtp_user = getenv('SMTP_USERNAME');
$ingress = getenv('INGRESS');
$admin_firstname = getenv('ADMIN_FIRSTNAME');
$admin_lastname = getenv('ADMIN_LASTNAME');
$admin_email = getenv('ADMIN_EMAIL');

if (!$passwd && !$smtp_user && !$ingress) die;

$conf = '/var/opt/persistent/configuration.php';
if (!file_exists($conf)) die;
require_once $conf;

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
    
    if ($passwd) {
        $st = $db->prepare("UPDATE tbladmins SET password=md5(?) WHERE username='Admin' and passwordhash=''");
        $st->execute(array($passwd));
    }

    if ($smtp_user) {
        $smtp_host = getenv('SMTP_HOST');
        $smtp_password = getenv('SMTP_PASSWORD');
        $smtp_port = getenv('SMTP_PORT');
        $smtp_protocol = getenv('SMTP_PROTOCOL');
        $domain = getenv('DOMAIN');
        $from_email = getenv('FROM_EMAIL');

        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SMTPUsername'");
        $st->execute(array($smtp_user));
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='MailType'");
        $st->execute(array('smtp'));

        if ($from_email) {
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='Email'");
            $st->execute(array($from_email));
            $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SystemEmailsFromEmail'");
            $st->execute(array($from_email));
        }
        else {
            if ($domain) {
                $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='Email'");
                $st->execute(array('noreply@' . $domain));
                $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SystemEmailsFromEmail'");
                $st->execute(array('noreply@' . $domain));
            }
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
            $st->execute(array($smtp_protocol));
        }
    }
    
    if ($domain) {
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='SystemURL'");
        $st->execute(array('http://' . $domain));
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='Domain'");
        $st->execute(array('http://' . $domain . '/'));
    }
    
    if ($ingress) {
        $st = $db->prepare("UPDATE tblconfiguration SET value=? WHERE setting='APIAllowedIPs'");
        $st->execute(array('a:1:{i:0;a:2:{s:2:"ip";s:' . strlen($ingress) . ':"' . $ingress . '";s:4:"note";s:7:"INGRESS";}}'));
    }
    
    if ($admin_firstname) {
        $st = $db->prepare("UPDATE tbladmins SET firstname=? WHERE username='Admin'");
        $st->execute(array($admin_firstname));
    }
    
    if ($admin_lastname) {
        $st = $db->prepare("UPDATE tbladmins SET lastname=? WHERE username='Admin'");
        $st->execute(array($admin_lastname));
    }
    
    if ($admin_email) {
        $st = $db->prepare("UPDATE tbladmins SET email=? WHERE username='Admin'");
        $st->execute(array($admin_email));
    }
    
} catch (PDOException $e) {
    die("Database error: " . $e->getMessage());
}