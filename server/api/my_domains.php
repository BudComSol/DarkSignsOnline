<?php

$rewrite_done = true;
require_once('function.php');

$type = $_GET['type'];
echo '2001';
if ($type == 'domain')
{
	$stmt = $db->prepare('SELECT i.id AS id, d.name AS name, d.ext AS ext, COUNT(s.id) AS subdomains FROM iptable AS i LEFT JOIN domain AS d ON d.id = i.id LEFT JOIN subdomain AS s ON s.hostid = i.id WHERE i.owner = ? AND i.regtype="DOMAIN" GROUP BY i.id;');
	$stmt->bind_param('i', $user['id']);
	$stmt->execute();
	$result = $stmt->get_result();
	while ($loop = $result->fetch_array())
	{
		echo $loop['name'].'.'.$loop['ext'];
		if ($loop['subdomains'] > 0)
			echo '*';
		echo '$newline';
	}
}
else if ($type == 'subdomain')
{
	$domain = $_GET['domain'];
	$dInfo = getDomainInfo($domain);
	if ($dInfo[0] <= 0)
	{
		die('Domain not found.');
	}
	else if ($dInfo[1] !== $user['id'])
	{
		die('Domain not found.');
	}

	$stmt = $db->prepare('SELECT name FROM subdomain WHERE hostid=?');
	$stmt->bind_param('i', $dInfo[0]);
	$stmt->execute();
	$result = $stmt->get_result();

	while ($loop = $result->fetch_array())
	{
		echo $loop['name'].'.'.$domain.'$newline';
	}
}
else if ($type == 'ip')
{
	$stmt = $db->prepare('SELECT ip FROM iptable WHERE owner=? AND regtype="IP"');
	$stmt->bind_param('i', $user['id']);
	$stmt->execute();
	$result = $stmt->get_result();
	while ($loop = $result->fetch_array())
	{
		echo $loop['ip'].'$newline';
	}
}
else
{
	echo 'Invalid type paramater.';
}
