<?php

// SQL DATABASE
$config['db_dsnw'] = 'PH_PHP_CONN_TYPE://PH_RCM_DB_USER:PH_RCM_DB_PASSWD@PH_SQL_SERVER_ADDRESS:PH_SQL_SERVER_PORT/PH_RCM_DB_NAME';

// LOGGING
$config['log_driver'] = 'syslog';
$config['syslog_facility'] = LOG_MAIL;

// IMAP
$config['default_host'] = 'PH_IMAP_SERVER';
$config['default_port'] = 143;
$config['imap_auth_type'] = 'LOGIN';
$config['imap_delimiter'] = '/';
// Required if you're running PHP 5.6 or later
$config['imap_conn_options'] = array(
    'ssl' => array(
        'verify_peer'  => false,
        'verify_peer_name' => false,
    ),
);

// SMTP
$config['smtp_server'] = 'tls://PH_SMTP_SERVER';
$config['smtp_port'] = 587;
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_auth_type'] = 'LOGIN';
// Required if you're running PHP 5.6 or later
$config['smtp_conn_options'] = array(
    'ssl' => array(
        'verify_peer'      => false,
        'verify_peer_name' => false,
    ),
);

// Use user's identity as envelope sender for 'return receipt' responses,
// otherwise it will be rejected by iRedAPD plugin `reject_null_sender`.
$config['mdn_use_from'] = true;

// SYSTEM
$config['force_https'] = true;
$config['login_autocomplete'] = 2;
$config['ip_check'] = true;
$config['des_key'] = 'PH_RCM_DES_KEY';
$config['cipher_method'] = 'AES-256-CBC';
$config['useragent'] = 'Roundcube Webmail'; // Hide version number
//$config['username_domain'] = 'PH_FIRST_DOMAIN';
//$config['mime_types'] = '/etc/mime.types';

// USER INTERFACE
$config['create_default_folders'] = true;
$config['quota_zero_as_unlimited'] = true;

// USER PREFERENCES
$config['default_charset'] = 'UTF-8';
//$config['addressbook_sort_col'] = 'name';
$config['draft_autosave'] = 60;
$config['default_list_mode'] = 'threads';
$config['autoexpand_threads'] = 2;
$config['check_all_folders'] = true;
$config['default_font_size'] = '12pt';
$config['message_show_email'] = true;
$config['layout'] = 'widescreen';   // three columns
//$config['skip_deleted'] = true;

// PLUGINS
$config['plugins'] = array('managesieve', 'password');

