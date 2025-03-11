<?php  // Moodle configuration file

require_once('/vendor/autoload.php');

// Load environment variables correctly
$dotenvPath = __DIR__; // Set correct path to .env
$dotenv = Dotenv\Dotenv::createImmutable($dotenvPath);
$dotenv->load();

// Ensure required environment variables are available
$required_env_vars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'SITE_URL', 'MOODLE_DATA_PATH'];
foreach ($required_env_vars as $var) {
    if (!isset($_ENV[$var])) {
        error_log("Warning: Missing required environment variable: $var");
    }
}

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'mysqli';
$CFG->dblibrary = 'native';
$CFG->dbhost    = $_ENV['DB_HOST'] ?? 'mysql';
$CFG->dbname    = $_ENV['DB_NAME'] ?? 'moodle';
$CFG->dbuser    = $_ENV['DB_USER'] ?? 'moodle';
$CFG->dbpass    = $_ENV['DB_PASSWORD'] ?? '';
$CFG->prefix    = '';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => isset($_ENV['DB_PORT']) ? intval($_ENV['DB_PORT']) : 3306,
  'dbsocket' => '',
  'dbcollation' => 'latin1_swedish_ci',
);

// Fix wwwroot handling to avoid CLI errors
if (php_sapi_name() === 'cli') {
    // CLI mode: Use default SITE_URL if missing
    $CFG->wwwroot = $_ENV['SITE_URL'] ?? 'https://moodle-950003-dev.apps.silver.devops.gov.bc.ca';
} else {
    // Web mode: Use HTTP_HOST if SITE_URL is missing
    $CFG->wwwroot = $_ENV['SITE_URL'] ?? (isset($_SERVER['HTTP_HOST']) ? 'https://' . $_SERVER['HTTP_HOST'] : '');
}

$CFG->dataroot  = $_ENV['MOODLE_DATA_PATH'] ?? '/vendor/moodle/moodledata/persistent';
// $CFG->themedir  = (isset($_ENV['MOODLE_DATA_MOUNT_PATH'])) ? $_ENV['MOODLE_DATA_MOUNT_PATH'].'/theme' : '/vendor/moodle/moodledata/theme';
$CFG->admin     = 'admin';
$CFG->alternateloginurl  = $_ENV['ALTERNATE_LOGIN_URL'] ?? '';

$CFG->directorypermissions = 0777;

// Ensure SSL proxy setting is only applied in the right environments
$CFG->sslproxy = isset($_ENV['SITE_URL']) && (stristr($_ENV['SITE_URL'], "gov.bc.ca") || stristr($_ENV['SITE_URL'], "apps-crc.testing"));

// Handle CLI environment issues
if (php_sapi_name() === 'cli') {
    $_SERVER['HTTP_HOST'] = parse_url($CFG->wwwroot, PHP_URL_HOST);
    $_SERVER['REQUEST_URI'] = '/';
}

// Debugging tools - only for development
if (isset($_GET['siteconfig']) && !stristr($_ENV['SITE_URL'] ?? '', "gov.bc.ca")) {
    echo '<p>CONFIG:</p><pre>', print_r($CFG, true), '</pre>';
}
if (isset($_GET['devphpinfo']) && !stristr($_ENV['SITE_URL'] ?? '', "gov.bc.ca")) {
    phpinfo();
}

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
