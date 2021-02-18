<?php
// http://www.dohvati.ga/freenom.php?hostname=__HOSTNAME__&IP=__IP__&username=__USERNAME__&password=__PASSWORD__
// username mandatory
// password mandatory
// domain=all|domain-name (default all)
// IP=auto|IP-address (default all)
// renew=true|false (default false)
// echo=true|false (default false)
// debug=true|false (default false)


$CONNECT_TIMEOUT = 60;
$DEBUG = false;
$ECHO_PROGRESS = false;
$MAX_RETRIES = 5;
$RETRY_SLEEP = 3;
$BACKOFF_SLEEP = 1.4;
$CURL_DEBUG_FILE = '/volume1/web/logs/freenom_curl.log';

$lastResponseCode = 0;
$lastResponse = '';
$loggedIn = false;
$freenom_log = 0;

header('Content-type: text/html; charset=utf-8');

function progress_log($msg) {
  global $ECHO_PROGRESS, $lastResponseCode;
  $msg = "$msg (last HTTP $lastResponseCode)";
  error_log($msg);
  if ($ECHO_PROGRESS) {
    echo "$msg <br/>";
    ob_flush();
    flush();
  }
}

function debug_progress_log($msg) {
  global $DEBUG;

  if ($DEBUG) {
    progress_log("DBG $msg");
  }
}

if (!isset($_GET['username']) || !isset($_GET['password'])) {
  exit('badparam');
}

$Username = $_GET['username'];
$Password = $_GET['password'];

$RequestedDomain = 'all';
if (isset($_GET['hostname'])) {
  $RequestedDomain = $_GET['hostname'];
}

$IP = 'auto';
if (isset($_GET['ip'])) {
  $IP = $_GET['ip'];
}

$Renew = false;
if (isset($_GET['renew'])) {
  $Renew = filter_var($_GET['renew'], FILTER_VALIDATE_BOOLEAN);
}

if (isset($_GET['echo'])) {
  $ECHO_PROGRESS = filter_var($_GET['echo'], FILTER_VALIDATE_BOOLEAN);
}
if (isset($_GET['debug'])) {
  $DEBUG = filter_var($_GET['debug'], FILTER_VALIDATE_BOOLEAN);
}

progress_log("Got args: $Username domain=$RequestedDomain IP=$IP");

$userAgents = array(
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/75.0.3770.142 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.108 Safari/537.36',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:69.0) Gecko/20100101 Firefox/69.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:66.0) Gecko/20100101 Firefox/66.0',
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2486.0 Safari/537.36 Edge/13.10586',
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.150 Safari/537.36 Edg/88.0.705.63",
  'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36',
  'Mozilla/5.0 (IE 11.0; Windows NT 6.3; Trident/7.0; .NET4.0E; .NET4.0C; rv:11.0) like Gecko',
  'Mozilla/5.0 (X11; Linux x86_64; rv:55.0) Gecko/20100101 Firefox/55.0',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 Safari/537.36',
  'Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.1.2 Mobile/15E148 Safari/604.1',
  'Mozilla/5.0 (Android 9.0; Mobile; rv:61.0) Gecko/61.0 Firefox/61.0',
  'Mozilla/5.0 (Linux; Android 7.0; SM-G892A Build/NRD90M; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/60.0.3112.107 Mobile Safari/537.36',
);

function curl_with_retry($ch)
{
  global $MAX_RETRIES, $RETRY_SLEEP, $BACKOFF_SLEEP;
  global $lastResponseCode, $lastResponse;
  // this function is called by curl for each header received
  curl_setopt($ch, CURLOPT_HEADERFUNCTION,
    function($ch, $header) use (&$headers)
    {
      $len = strlen($header);
      $header = explode(':', $header, 2);
      if (count($header) < 2) // ignore invalid headers
          return $len;

      $headers[strtolower(trim($header[0]))][] = trim($header[1]);

      return $len;
    }
  );
  $headers = [];
  $lastResponse = curl_exec($ch);
  $retry = 0;
  $err = curl_errno($ch);
  $lastResponseCode = curl_getinfo($ch, CURLINFO_HTTP_CODE); 
  $retrySleep = $RETRY_SLEEP;
  while (($err != 0 || $lastResponseCode >= 500) && $retry < $MAX_RETRIES) {
    progress_log("CurlError: $err, $lastResponseCode");
    sleep($retrySleep);
    $headers = [];
    $lastResponse = curl_exec($ch);
    $err = curl_errno($ch);
    $retry++;
    $retrySleep = $retrySleep + pow($BACKOFF_SLEEP, $retry);
  }

  return array('headers' => $headers, 'body' => $lastResponse);
}

function curl_get($ch, $url, $follow = false)
{
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_POST, false);
  curl_setopt($ch, CURLOPT_HTTPGET, true);
  curl_setopt($ch, CURLOPT_FOLLOWLOCATION, $follow);
  return curl_with_retry($ch)['body'];
}

function curl_html_dom_get($ch, $url, $follow = false)
{
  $response = curl_full_get($ch, $url, $follow);
  return $response["dom"];  
}

# Retrieves both DOM and raw content of page
function curl_full_get($ch, $url, $follow = false)
{
  $response = curl_get($ch, $url, $follow);
  $dom = new DOMDocument();
  @$dom->loadHTML($response);
  return array('dom' => $dom, 'raw' => $response);
}

# Sends form post request to URL
function curl_post($ch, $url, $form, $follow = false)
{
  curl_setopt($ch, CURLOPT_URL, $url);
  curl_setopt($ch, CURLOPT_HTTPGET, false);
  curl_setopt($ch, CURLOPT_POST, true);
  curl_setopt($ch, CURLOPT_FOLLOWLOCATION, $follow);
  curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($form));
  curl_setopt($ch, CURLOPT_REFERER, 'https://my.freenom.com/clientarea.php');
  return curl_with_retry($ch);
}

# Called on page cleanup. Closes resources and logs outs.
function cleanup($ch)
{
  global $DEBUG, $loggedIn, $freenom_log;

  try {
    if ($loggedIn) {
      curl_setopt($ch, CURLOPT_URL, "https://my.freenom.com/logout.php");
      curl_with_retry($ch);
    }  
  }
  finally {
    try {
      if ($DEBUG) {
        fclose($freenom_log);
      }
    }
    finally {
      curl_close($ch);
    }
  }
}

function get_ip($ch)
{
  progress_log('Retrieving my IP address from http://checkip.amazonaws.com');
  $ip = trim(curl_get($ch, 'http://checkip.amazonaws.com'));
  progress_log("Retrieved address $ip");
  return $ip;
}

// Fetch domain records from 
function fetch_domain($ch, $href, $domain)
{
  debug_progress_log("Fetching records for $domain");
  $domDomainAdmin = curl_html_dom_get($ch, "https://my.freenom.com/$href");
  debug_progress_log("Got answer for doman $domain");
  $records = array();
  $lastRecord = -1;
  foreach ($domDomainAdmin->getElementsByTagName('input') as $recordInput) {
    $recordName = $recordInput->getAttribute('name');
    debug_progress_log("Record candidate: $recordName");
    
    if (preg_match('/records\[([0-9]+)\]/', $recordName, $output_array)) {
      $idx = intval($output_array[1]);
      if ($idx > $lastRecord) {
        $lastRecord = $idx;
      }
      debug_progress_log("Found record: $idx $recordName {${$recordInput->getAttribute('value')}}");
      $records[$recordName] = $recordInput->getAttribute('value');
    }
  }

  debug_progress_log("Total records: $lastRecord");
          
  return array('records' => $records, 'lastRecord' => $lastRecord);
}

// Updates domain A record with global IP address
function update_domain($ch, $domain, $domainId, $domainRecords, $ip)
{
  $records = $domainRecords['records'];
  $lastRecord = $domainRecords['lastRecord'];

  $domainUrl = "https://my.freenom.com/clientarea.php?managedns=$domain&domainid=$domainId";

  $foundRecord = false;
  for ($i = 0; $i < $lastRecord; $i++) {
    debug_progress_log("Processsing record $i type " . $records["records[$i][type]"] . " value '" . $records["records[$i][value]"] . "' name '" . $records["records[$i][name]"] . "'");
    # If record is A record, update it
    if (($records["records[$i][name]"] == '') &&
        ($records["records[$i][type]"] == 'A')) {
      $foundRecord = true;
      debug_progress_log("Found A record at index $i " . $records["records[$i][value]"] );
      if ($records["records[$i][value]"] != $ip) {
        debug_progress_log("IP is diffferent, will be updated" . $records["records[$i][value]"] );
        $form = array(
          'dnsaction'          => 'modify',
          "records[$i][name]"  => '',
          "records[$i][type]"  => 'A',
          "records[$i][ttl]"   => '600',
          "records[$i][value]" => $ip
        );
        // TODO check result
        curl_post($ch, $domainUrl, $form);
        progress_log("Replaced IP record for $domain");

      }
      else {
        progress_log("IP address not changed for $domain");
      }
      break;
    }
  }
  # If A record was not found, adding new one
  if (!$foundRecord) {
    debug_progress_log("Adding new record for $domain");
    $form = array(
      'dnsaction'                   => 'add',
      "records[$lastRecord][name]"  => '',
      "records[$lastRecord][type]"  => 'A',
      "records[$lastRecord][ttl]"   => '600',
      "records[$lastRecord][value]" => $ip
    );
    // TODO check result
    curl_post($ch, $domainUrl, $form);
    progress_log("Added new record for $domain");
  }
}

$UserAgent = $userAgents[random_int(0, count($userAgents)-1)];
debug_progress_log("User agent: $UserAgent");

$ch = curl_init();
register_shutdown_function( 'cleanup_curl', $ch );

// set URL and other appropriate options
$options = array(   
  CURLOPT_USERAGENT => $UserAgent,
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_CONNECTTIMEOUT => $CONNECT_TIMEOUT,
  CURLOPT_VERBOSE => $DEBUG,
  CURLOPT_FOLLOWLOCATION => true,
  CURLOPT_COOKIEFILE => "",
  CURLOPT_COOKIESESSION => true,
  CURLOPT_REFERER, 'https://my.freenom.com/clientarea.php',
);

curl_setopt_array($ch, $options);

if ($DEBUG) {
  debug_progress_log("Opening file '$CURL_DEBUG_FILE'");
  $freenom_log = fopen($CURL_DEBUG_FILE, 'wb');
  curl_setopt($ch, CURLOPT_STDERR, $freenom_log);
}


if ($IP == 'auto') {
  $IP = get_ip($ch);
}

debug_progress_log('Getting token');
$domLogin = curl_html_dom_get($ch, 'https://my.freenom.com/clientarea.php', true);
debug_progress_log('Got token reply');
// Token to send in login request
foreach ($domLogin->getElementsByTagName('input') as $input) {
  if ($input->getAttribute('name') == 'token') {
    $token = $input->getAttribute('value');
    break;
  }
}

if (empty($token)) {
  progress_log('Token not found.');
  exit('badconn');
}

debug_progress_log("Got token");
$loginPost = array(
  'username' => $Username,
  'password' => $Password,
  'token'    => $token
);

debug_progress_log("Authentication");

$response = curl_post($ch, "https://my.freenom.com/dologin.php", $loginPost);
// || str_contains($response['headers'], 'clientarea.php?incorrect=true'))

if ($lastResponseCode == 403 || strpos($response['body'], 'Login Details Incorrect') !== false || $lastResponseCode >= 403 ) {
  progress_log("Authentication failed");
  exit("noauth");
}
debug_progress_log('Authentication OK');
$loggedIn = true;
$domAllDomains = curl_html_dom_get($ch, 'https://my.freenom.com/clientarea.php?action=domains&itemlimit=all');
debug_progress_log('Got domains');
$foundDomain = false;
foreach($domAllDomains->getElementsByTagName('a') as $link) {
  $hrefDomain = $link->getAttribute('href');
  if (strpos($hrefDomain, 'action=domaindetails') !== false) {
    debug_progress_log("Fetching domain info from $hrefDomain");
    $domDomainDetails = curl_html_dom_get($ch, "https://my.freenom.com/$hrefDomain");
    foreach ($domDomainDetails->getElementsByTagName('a') as $managedns) {
      $hrefDomainDetails = $managedns->getAttribute('href');
      if (preg_match('/\/clientarea.php\?managedns=([a-z\-\.]+)\&domainid=([0-9]+)/', $hrefDomainDetails, $matches)) {
        $currentDomain = $matches[1];
        $domainId = $matches[2];
        debug_progress_log("Domain details: $currentDomain $domainId");
        if ($RequestedDomain == 'all' || $currentDomain == $RequestedDomain) {
          $foundDomain = true;
          $fetchedDomain = fetch_domain($ch, $hrefDomainDetails, $currentDomain);
          update_domain($ch, $currentDomain, $domainId, $fetchedDomain, $IP);
        }
      }
    }
  }
}

if (!$foundDomain) {
  progress_log("No domains found for update. Requested domain was '$RequestedDomain'.");
  exit('nohost');
}

function renew($ch, $Domain) {
  debug_progress_log('Renewing domains..');
  $domRenewals = curl_html_dom_get($ch, 'https://my.freenom.com/domains.php?a=renewals&itemlimit=all');
  foreach ($domRenewals->getElementsByTagName('a') as $renewalLinks) {
    $renewLink = $renewalLinks->getAttribute('href');
    if (strpos($renewalLinks, 'a=renewdomain') !== false)
    {
      debug_progress_log("Check domain renewal at $renewLink...");
      $renewPage = curl_full_get($ch, "https://my.freenom.com/$renewLink");
      if (strpos($renewPage['raw'], 'Minimum Advance Renewal is 14 Days for Free Domains') === false)
      {
        if ($Domain == 'all' || strpos($renewPage['raw'], "<td>$Domain</td>") !== false) {
          $form = array();
          foreach ($renewPage['dom']->getElementsByTagName('input') as $input) {
            $form[$input->getAttribute('name')] = $input->getAttribute('value');
          }
          $renewalPeriod = 12;
          $renewalIdValue =$form['renewalid'];
          $form["renewalperiod[$renewalIdValue]"] = $renewalPeriod;
          debug_progress_log("Renewing domain at $renewLink...");
          curl_post($ch, 'https://my.freenom.com/domains.php?submitrenewals=true', $form);
          progress_log('Completed freenom update.');
        }
        else {
          debug_progress_log("Domain at $renewLink is ignored.");
        }
      }
      else {
        debug_progress_log("Domain at $renewLink not open for renewal.");      
      }
    }
  }
}

if ($Renew) {
  renew($ch, $RequestedDomain);
}

progress_log('Completed freenom update.');
exit('good');

?>