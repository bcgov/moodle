<?php

/* Servers configuration */
$i = 0;

$cfg['blowfish_secret'] = 'h]C23+{nqW$omNosTIkCwC$%z-LTcy%p6_j$|$Wv[mwngi~|e'; //What you want

// Allow any server
$cfg['AllowArbitraryServer'] = true;

//Checking Active DBMS Servers

//Check if MySQL and MariaDB with MariaDB on default port
$i++;
if($mariaFirst) $i++;
$cfg['Servers'][$i]['verbose'] = 'moodle-mysql';
$cfg['Servers'][$i]['host'] = (isset(getenv('DB_HOST')) ? getenv('DB_HOST') : 'moodle-mysql';
$cfg['Servers'][$i]['port'] = (isset(getenv('DB_PORT'))) ? getenv('DB_PORT') : 3306;
$cfg['Servers'][$i]['extension'] = 'mysqli';
$cfg['Servers'][$i]['auth_type'] = 'config';
$cfg['Servers'][$i]['user'] = (isset(getenv('DB_USER'))) ? getenv('DB_USER') : 'moodle';
$cfg['Servers'][$i]['password'] = (isset(getenv('DB_PASSWORD'))) ? getenv('DB_PASSWORD') : 'default_password';

$i++;
$cfg['Servers'][$i]['verbose'] = 'OCP DB - TEST';
$cfg['Servers'][$i]['host'] = isset(getenv('DB_HOST2')) ? getenv('DB_HOST2') : 'localhost';
$cfg['Servers'][$i]['port'] = (isset(getenv('DB_PORT2'))) ? getenv('DB_PORT2') : 3307;
$cfg['Servers'][$i]['extension'] = 'mysqli';
$cfg['Servers'][$i]['auth_type'] = 'config';
$cfg['Servers'][$i]['user'] = (isset(getenv('DB_USER2'))) ? getenv('DB_USER2') : 'moodle';
$cfg['Servers'][$i]['password'] = (isset(getenv('DB_PASSWORD2'))) ? getenv('DB_PASSWORD2') : 'default_password';

// Suppress Warning about pmadb tables
$cfg['PmaNoRelation_DisableWarning'] = true;

// To have PRIMARY & INDEX in table structure export
$cfg['Export']['sql_drop_table'] = true;
$cfg['Export']['sql_if_not_exists'] = true;

$cfg['MySQLManualBase'] = 'http://dev.mysql.com/doc/refman/5.7/en/';
/* End of servers configuration */

$cfg['Servers'] [$i] ['LoginCookieValidity'] = 9223372036854775805;

echo '<p>CONFIG:</p><pre>',print_r($cfg),'</pre>';

?>
