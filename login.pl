#!/usr/bin/perl 

use CGI;
use CGI::Carp qw/fatalsToBrowser warningsToBrowser/;
use CGI::Session ( '-ip_match' );

use DBI;

$q = new CGI;

unless ($ENV{'REQUEST_METHOD'} eq 'GET') 
{
	my $db = DBI->connect("dbi:SQLite:dbname=sqlitedb/stuff.db","","") or die "database issues";

	$login = $q->param('login');
	$pass = crypt($q->param('pass'),"pie");
	$register = $q->param('new');

	if ($register=~/true/)
	{
		my $existing=$db->selectrow_array("SELECT login FROM users WHERE login=\'$login\'");
		if ($existing)
		{
			$err="username exists.<br>";
		}
		else
		{
			$db->do("INSERT INTO users (login,pass) VALUES (\'$login\',\'$pass\')");
			if ($db->err()) { die "$DBI::errstr\n"; }
		    	$db->commit();
			
			$session = new CGI::Session("driver:File",undef,{'Directory'=>"/tmp"});
       		        $session->param( 'login', $login );
       	         	$cookie = $q->cookie(CGISESSID => $session->id);
			print $q->redirect(-location => 'con_v_time.pl', -cookie => $cookie);
			exit;
		}
	}
	elsif($login ne '' and $pass ne '')
	{
				
		my $authdata=$db->selectrow_array("SELECT pass FROM users WHERE login=\'$login\'");
		if ($authdata=~/$pass/)
		{
			$session = new CGI::Session("driver:File",undef,{'Directory'=>"/tmp"});
			$session->param( 'login', $login );
			$cookie = $q->cookie(CGISESSID => $session->id);
			print $q->redirect(-location =>'con_v_time.pl', -cookie => $cookie);
			exit;
		}
		else
		{
				$err="password incorrect.<br>";
		}
	}
	else
	{
		print "sad face :(";
	}
    	$db->disconnect();

}
undef($login);
undef($pass);
undef($authenticate);

print $q->header;
print "<center>
	$err";
print '
	<form method="post">
	username: <input type="text" name="login" length=12 maxlength=12>
	<br />
	password: <input type="password" name="pass" length=12 maxlength=12>
	<br />
	new user: <input type="checkbox" name="new" value="true">
	<br />
	<input type="submit">
       	</form>
	';
print $q->end_html();

