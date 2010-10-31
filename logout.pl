#!/usr/bin/perl -w

use CGI;
use CGI::Session;

$q = new CGI;
$cookie = $q->cookie(-name => "session");

if ($cookie) 
{
	CGI::Session->name($cookie);

}

$session = new CGI::Session("driver:File",$cookie,{'Directory'=>"/tmp"}) or die "$!";
$session->delete();
print $q->redirect('con_v_time.pl');
