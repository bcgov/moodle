<?php  // Moodle configuration file

require_once('/vendor/autoload.php');

$dotenv = Dotenv\Dotenv::createImmutable('/');
$dotenv->load();

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = (isset($_ENV['DB_HOST'])) ? $_ENV['DB_HOST'] : 'mysql';
$CFG->dbname    = (isset($_ENV['DB_NAME'])) ? $_ENV['DB_NAME'] : 'moodle';
$CFG->dbuser    = (isset($_ENV['DB_USER'])) ? $_ENV['DB_USER'] : 'moodle';
$CFG->dbpass    = (isset($_ENV['DB_PASSWORD'])) ? $_ENV['DB_PASSWORD'] : '';
$CFG->prefix    = '';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => (isset($_ENV['DB_PORT'])) ? intval($_ENV['DB_PORT']) : 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

$CFG->wwwroot   = (isset($_ENV['SITE_URL'])) ? $_ENV['SITE_URL'] : 'https://moodle-950003-dev.apps.silver.devops.gov.bc.ca';
$CFG->dataroot  = (isset($_ENV['MOODLE_DATA_PATH'])) ? $_ENV['MOODLE_DATA_PATH'] : '/vendor/moodle/moodledata/persistent';
// $CFG->themedir  = (isset($_ENV['MOODLE_DATA_MOUNT_PATH'])) ? $_ENV['MOODLE_DATA_MOUNT_PATH'].'/theme' : '/vendor/moodle/moodledata/theme';
$CFG->admin     = 'admin';
$CFG->alternateloginurl  = (isset($_ENV['ALTERNATE_LOGIN_URL'])) ? $_ENV['ALTERNATE_LOGIN_URL'] : '';

$CFG->directorypermissions = 0777;

$CFG->sslproxy = ( isset($_ENV['SITE_URL']) && ( stristr($_ENV['SITE_URL'], "gov.bc.ca") || stristr($_ENV['SITE_URL'], "apps-crc.testing") )  ) ? true : false; // Only use in OCP environments

$CFG->getremoteaddrconf = 0;

// Display configuration using /?config param in url - but not on internet-facing sites
if (isset($_GET['siteconfig']) && !stristr(@$_ENV['SITE_URL'], "gov.bc.ca")) echo '<p>CONFIG:</p><pre>',print_r($CFG),'</pre>';
if (isset($_GET['devphpinfo']) && !stristr(@$_ENV['SITE_URL'], "gov.bc.ca")) phpinfo();

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
