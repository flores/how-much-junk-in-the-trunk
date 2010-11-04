#!/usr/bin/perl

use CGI;
use CGI::Session;
use DBI;

$q = new CGI;

# did this guy login?

$cookie = $q->cookie(-name => "session");
if ($cookie) {
        CGI::Session->name($cookie);
}
$session = new CGI::Session("driver:File",$cookie,{'Directory'=>"/tmp"}) or die "$!";
$login = $session->param('login');

unless ($login)
{
	$q->redirect(-location => 'login.pl');
}

my $db = DBI->connect("dbi:SQLite:dbname=sqlitedb/stuff.db","","") or die "database issues";
my $saved_graphs = $db->selectrow_array("SELECT saved_graphs FROM users WHERE login=\'$login\'");

print $q->header;
print '<center>';

unless($saved_graphs)
{
	print "You don't have any saved graphs, $login.<br>
		<a href='con_v_time.pl'>Let's make some!</a>";
}
else
{
	print "<p align='right'><font size='2'>\n";
        print "Hi, $login | <a href='con_v_time.pl'>make more graphs</a> | <a href='logout.pl'>logout</a>";
	print "</font></p>\n";
	
	$saved_graphs=~s/^\s//g;
	my @graphs = split ('\s+',$saved_graphs);
	@graphs = sort {$b <=> $a} (@graphs);

	print '<table>
		<tr>
			<th>click for larger</th>
			<th>data</th>
		</tr>';
	
	foreach $one (@graphs)
	{
		my $vars = $db->selectrow_hashref("SELECT * FROM graphs WHERE id=\'$one\'");

# $vars->{pwc_freq} is weeks between water changes.  We're changing this to water changes per month for readability.
		if ($vars->{pwc_freq} =4)
		{
			$pwc_freq = 1;
		}
		if ($vars->{pwc_freq} =1)
                {
                        $pwc_freq = 4;
                }
		
		print "<tr>
			<th rowspan=5><a href=\'images/con_v_time.$one.png\' target='_blank'><img src=\'images/con_v_time.$one\.png\' width='200' height='100'></a></th>
			</tr>
				<tr>
					<td>$vars->{dose} ppm Stuff dosed $vars->{dose_freq} times a week</td>
				</tr>
				<tr>
					<td>$vars->{pwc} % water change $pwc_freq times a month</td>
				</tr>
				<tr>
					<td>Modelled for $vars->{length} days</td>
				</tr>
				<tr>
					<td>";
		if ($vars->{dose_pwc} ne $vars->{dose})
		{	print "Dosing $vars->{dose_pwc} ppm per water change.<br />"; }
		if ($vars->{food_ppm} > 0)
		{	print "Feeding $vars->{food_ppm} ppm from food each day.<br />"; }
		if ($vars->{dose_initial} ne  $vars->{dose})
		{	print "We started with $vars->{dose_initial} ppm Stuff.<br />"; }
		if ($vars->{regress} =~ /true/)
		{	print "We regressed this data into a linear graph."; }
	 	print "</td></tr>";
		print "<tr><td><hr width=100%></td></tr>";
		
	}
	print "</table>";
	$db->disconnect();
}

