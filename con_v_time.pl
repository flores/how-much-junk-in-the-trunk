#!/usr/bin/perl 

use CGI::Form;
use CGI::Session;
use CGI; 
use GD::Graph::area;
use Statistics::OLS;
use DBI;


$q = new CGI;

# did this guy login?

$cookie = $q->cookie(-name => "session");
if ($cookie) {
	CGI::Session->name($cookie);
}
$session = new CGI::Session("driver:File",$cookie,{'Directory'=>"/tmp"}) or die "$!";
$login = $session->param('login');


# are we passing variables from calc.petalphile.com?

my $stuff  = $q->param('stuff');
my $dose   = $q->param('dose');

if ($stuff =~ /(\w+);dose=(.*)/)
{
	$stuff = "$1";
	$dose = "$2";
}
if ($stuff !~ /\w/)
{
	$stuff = "Stuff";
}

print $q->header();

print "<title>Concentrations of $stuff vs Time and Plant Uptake using The Estimative Index</title>";
print "<p align='right'><font size='2'>\n";
if ($login)
{
	print "Hi $login | <a href='saved_graphs.pl'>view your saved graphs</a> | <a href='logout.pl'>logout</a>";
}
else
{
	print "<a href='login.pl'>login/register</a> to save your graphs!";
}
print "</font></p>\n";
		
print "<center>\n";

if ($ENV{'REQUEST_METHOD'} eq 'GET') {

        undef($compound);
        undef($doses_wk);
        undef($tank);
        undef($pwc);
#        &printForm($q);


} else {

	my $dose=$q->param('dose');
	my $dose_freq_value=$q->param('dose_freq');
	my $dose_type=$q->param('dose_type');
	my $compound=$q->param('compound');
	my $tank=$q->param('tank');
	my $tank_units=$q->param('tank_units');
	my $pwc=$q->param('pwc');
	my $pwc_freq_word=$q->param('pwc_freq');
	my $uptake_known=$q->param('known_uptake');
	my $uptake_known_units=$q->param('known_uptake_units');
	my $dose_pwc=$q->param('dose_pwc');
	my $tap_conc=$q->param('tap_conc');
	my $initial=$q->param('initial');
	my $food_mg=$q->param('food_mg');
	my $food_conc=$q->param('food_conc');
	my $food_units=$q->param('food_units');
	my $length=$q->param('length');
	my $csv=$q->param('CSV');
	my $regress=$q->param('regress');
	my $save=$q->param('save');
	    	 

# dirty input validation.  
	print "<font color=red>";
	$err=0;
	if ( $dose!~/^\.?[\d]+\.?\d*$/ || $dose=~/.*\..*\./ || $dose<=0 )
	{
		print "$stuff must be a real number.<br />\n";
		$err=1;
	}
	if ( $pwc!~/^\.?[\d]+\.?\d*$/ || $pwc=~/.*\..*\./ || $pwc=~/\%/ || $pwc<0  )
	{
		print "Your water change amount must be a real number.<br />\n";
		$err=1;
	}
	if ( $tap_conc && ($tap_conc!~/^\.?[\d]+\.?\d*$/ || $tap_conc=~/.*\..*\./ || $tap_conc=~/\%/ || $tap_conc<=0 ) )
	{
		print "Tap water's concentration of $stuff must be a real number.<br />\n";
		$err=1;
	}
	if ( $dose_freq_value=~/1/ && $dose_pwc && $pwc_freq_word=~/^week$/)
	{
		print "When dosing once a week and weekly water changes you can only use the original dose.  It is the same as your water change dose.<br />\n";
		$err=1;
	}

# dirty input validation on the optional stuff
	if ( ($food_mg > 0) && ( $food_mg!~/^\.?[\d]+\.?\d*$/ || $food_mg=~/.*\..*\./ || $food_mg=~/-/) )
	{
		print "milligrams food must be a real positive number.<br />\n";
		$err=1;
	}
	if ( ( $food_mg > 0 && !$food_conc ) || ( !$food_mg && $food_conc ) || ($tank && (!$food_mg || !$food_conc ) )  )
	{
		print "You must include mg food, percent $stuff in that food, and tank gallons when using this option<br />\n";
		$err=1;
	}
	if ( ($tank > 0) && ( $tank!~/^\.?[\d]+\.?\d*$/ || $tank=~/.*\..*\./ || $tank=~/-/) )
	{
		print "Tank volume must be a real positive number.<br />\n";
		$err=1;
	}
	if ($tank && $tank <=0 )
	{
		print "Tank volume must be a real positive number.<br />\n";
		$err=1;
	}
	if ( $initial && ( $initial!~/^\.?[\d]+\.?\d*$/ || $initial=~/.*\..*\./ || $initial=~/-/) )
	{
		print "Your starting ppm of $stuff must be a real positive number.<br />\n";
		$err=1;
	}
	if ( $dose_pwc && ( $dose_pwc!~/^\.?[\d]+\.?\d*$/ || $dose_pwc=~/.*\..*\./ || $dose_pwc=~/-/) )
	{
		print "Your dose at water change must be a real positive number.<br />\n";
		$err=1;
	}
	print "</font>";
# / dirty input validation

# If the user did not enter a specific dose on pwc, it's the regular dose (we always dose on pwc days)
	if ( !$dose_pwc)
	{
		$dose_pwc=$dose;
	}

# let's add whatever is in the tap water
	if ( !$tap_conc)
	{
		$tap_conc=0;
	}

# ... and add what's in tap to the water change calculation	
	$dose_pwc=$dose_pwc + ($tap_conc * $pwc / 100);

# schedule stuff
	if ($pwc_freq_word=~/week/)
	{
	$pwc_freq=1;
	}
	if ($pwc_freq_word=~/two week/)
	{
	$pwc_freq=2;
	}
	if ($pwc_freq_word=~/month/)
	{
	$pwc_freq=4;
	}
	
	if ($length=~/^month$/)
	{
	$length=28;
	}
	if ($length=~/^three months$/)
	{
	$length=91;
	}
	if ($length=~/^six months$/)
	{
	$length=182;
	}
	if ($length=~/^year$/)
	{
	$length=364;
	}
	
	if ($uptake_known=~/[A-Z]|[a-z]|^0$|%|\*|\..*\./)
	{
	print "Weekly uptake rate must be a real number.";
	}

# added uptake_known after setting up arrays, quick and dirty to add this feature
	if ($uptake_known < 0)
	{
	$uptake_known=0.90;
	}
	else
	{
	if ( ($uptake_known > 0) && ($uptake_known_units =~ /%/) )
	{
		$uptake_known=$uptake_known/100;
	}
	elsif ( ($uptake_known > 0) && ($uptake_known_units =~ /ppm/) )
	{
		$uptake_known=$uptake_known/($dose * $dose_freq_value);
	}
	else { $uptake_known = 0.90; }
	}

	my $dose_freq=$dose_freq_value;


	if ($initial)
	{
		$dose_initial=$initial;
	}
	else
	{
		$dose_initial=$dose_pwc;
	}

# uptake
# does food input affect it
	my ($food_ppm,$vol);
            	if ($food_mg > 0)
	{
		if ($tank_units=~/gal/)
             		{
                     		$vol=$tank*3.78541178;
             		}
             		if ($tank_units=~/L/)
             		{
                     		$vol=$tank;
             		}
		if ($food_units=~/mg/)
		{
			$food_conc = $food_conc / 10000;
		}
		$food_ppm=  $food_mg * $food_conc / 100 / $vol;

# animal retention of food is 10% per PlantBrain's estimate.  The rest is excrement, aka plant fertilizer.
		$food_ppm = $food_ppm*.9;
	
# and we'll convert that to a daily amount.  We may let the user input how often they feed, later...	
		$food_ppm=$food_ppm/7;
		}
	else
	{
		$food_ppm=0;
	}	 

	if ($err==0) 
	{

# does this already exist in the database?
		my $db = DBI->connect("dbi:SQLite:dbname=sqlitedb/stuff.db","","") or die "database issues";
		my $existinggraph=$db->selectrow_array("SELECT id FROM graphs WHERE dose=\'$dose\' AND dose_freq=\'$dose_freq\' AND pwc=\'$pwc\' AND pwc_freq=\'$pwc_freq\' AND dose_pwc=\'$dose_pwc\' AND food_ppm=\'$food_ppm\' AND dose_initial=\'$dose_initial\' AND length=\'$length\' AND regress=\'$regress\' AND uptake_known=\'$uptake_known\'");
		if ($existinggraph)
		{
			$image=$existinggraph;
		}
		else
		{
			my @uptake_0=();			
			my @uptake_10=();			
			my @uptake_25=();
			my @uptake_50=();
			my @uptake_75=();
			my @uptake_known=();
			my @doseday=();
			my @pwcday=();
			my @foodppm=();	

# building the data.  these different arrays by uptake rates is the gist/point of the script.		
			my $uptake_rate_25 = ($dose * $dose_freq + $food_ppm) / 7 * 0.25;
			my $uptake_rate_50 = ($dose * $dose_freq + $food_ppm) / 7 * 0.50;
			my $uptake_rate_75 = ($dose * $dose_freq + $food_ppm) / 7 * 0.75;
			my $uptake_rate_90 = ($dose * $dose_freq + $food_ppm) / 7 * $uptake_known;

			push (@uptake_0, $dose_initial);
			push (@uptake_25, $dose_initial);
			push (@uptake_50, $dose_initial);
			push (@uptake_75, $dose_initial);
			push (@uptake_known, $dose_initial);
	
			my (@days);
			push(@days,1);
			push(@doseday,$dose_initial);
			push(@pwcday,0);
			my $day=2;
#pie is just a marker that becomes 1 on pwc day
			my $pie=2;

# length is how long we're building this model...		
			while ($day < ( $length + 1 ) )
			{
				
				my $now_0=@uptake_0[$#uptake_0];
				my $now_25=@uptake_25[$#uptake_25];
				my $now_50=@uptake_50[$#uptake_50];
				my $now_75=@uptake_75[$#uptake_75];
				my $now_90=@uptake_known[$#uptake_known];

# always evenly divisible on pwc day.	
				my $pwc_day = $day / ( 7 * $pwc_freq );
		
				if ( $pwc_day !~ /\./ )
				{
					$now_0 = $now_0 * ( (100 - $pwc ) / 100 );
					$now_25 = $now_25 * ( (100 - $pwc ) / 100 );
					$now_50 = $now_50 * ( (100 - $pwc ) / 100 );
					$now_75 = $now_75 * ( (100 - $pwc ) / 100 );
					$now_90 = $now_90 * ( (100 - $pwc ) / 100 );
					push(@pwcday,$pwc);
					$pie=1;
				}
# to avoid undefs for the csv...
				else
				{
					push(@pwcday,0);
				}

# daily dosing
				if ( ( $dose_freq=~/7/ ) && ( $pie > 1) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}

# every possible dosing day in a month for 3 or 4x a week dosing, regardless of pwc schedule
				elsif ( $pie=~/^(3|5|8)$|10|12|15|17|19|22|24|26/ && ($dose_freq=~/3|4/ && $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}
# ... except for these for 4x a week dosing
				elsif ( $pie=~/^7$|14|21|28/ && ($dose_freq=~/4/ && $pie > 1) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}

# twice a week dosing.  If we change water on a Sunday, we're dosing on Sunday and Wednesday.
				elsif ( $pie=~/^3$|10|17|24/ && ($dose_freq=~/2/ && $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}

# All this stuff is dependent on pwc schedule, as opposed to dosing schedule above.
# pwc dose day!	
				elsif ( $pie =~ /^1$/ )
				{
					$now_0 = $now_0+$dose_pwc;
					$now_25 = $now_25+$dose_pwc;
					$now_50 = $now_50+$dose_pwc;
					$now_75 = $now_75+$dose_pwc;
					$now_90 = $now_90+$dose_pwc;
					push(@doseday,$dose_pwc);
				}

# once a month partial water changes
				elsif ( $pwc_freq == 4  && ( $dose_freq == 1 && $pie =~ /^(7|14|21)$/ ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}

# twice a month partial water changes
				elsif ( $pwc_freq == 2 && ( $dose_freq == 1 && $pie == 7 ) )
				{
					$now_0 = $now_0+$dose;
		                        $now_25 = $now_25+$dose;
		                        $now_50 = $now_50+$dose;
		                        $now_75 = $now_75+$dose;
					push(@doseday,$dose);
				}
                                      

				else 
				{
					push(@doseday,0);
				}

# then we add how much we're adding through food/fish waste
				$now_0 = $now_0 + $food_ppm;
				$now_25 = $now_25 - $uptake_rate_25 + $food_ppm;
				$now_50 = $now_50 - $uptake_rate_50 + $food_ppm;
				$now_75 = $now_75 - $uptake_rate_75 + $food_ppm;
				$now_90 = $now_90 - $uptake_rate_90 + $food_ppm;

# and store it in the array
				push (@uptake_0,$now_0);
				push (@uptake_25,$now_25);
				push (@uptake_50,$now_50);
				push (@uptake_75,$now_75);
				push (@uptake_known,$now_90);
				push (@days,$day);
				$pie++;
				$day++;
			}
	
			print "<br />";

#Regression
			if ($regress=~/true/)
			{
				my $rs_0 = Statistics::OLS->new; 
				my $rs_25 = Statistics::OLS->new; 
				my $rs_50 = Statistics::OLS->new; 
				my $rs_75 = Statistics::OLS->new; 
				my $rs_90 = Statistics::OLS->new; 
				$rs_0->setData (\@days, \@uptake_0);
				$rs_25->setData (\@days, \@uptake_25);
				$rs_50->setData (\@days, \@uptake_50);
				$rs_75->setData (\@days, \@uptake_75);
				$rs_90->setData (\@days, \@uptake_known);
				$rs_0->regress();
				$rs_25->regress();
				$rs_50->regress();
				$rs_75->regress();
				$rs_90->regress();
				@uptake_0 = $rs_0->predicted();
				@uptake_25 = $rs_25->predicted();
				@uptake_50 = $rs_50->predicted();
				@uptake_75 = $rs_75->predicted();
				@uptake_known = $rs_90->predicted();
			}

# Graphing
# the data array of arrays will be our graph
			my @data = ();
			push(@data,\@days);
			push(@data,\@uptake_0);
			push(@data,\@uptake_25);
			push(@data,\@uptake_50);
			push(@data,\@uptake_75);
			push(@data,\@uptake_known);

#get maximum limit for y axis
			my ($y_max,$y_inc);
			foreach my $one (@uptake_0)
       		      	{
               		 	$y_max = $one if $one > $y_max;
				$y_min = $one if $one < $y_min;
             		}

# 10% buffer
	               	$y_max=$y_max*1.1;

# make y-axis increments such that we don't get a shitton of noise after the decimal 
			if ($y_min < 0)
			{
				my $y_range=$y_max - $y_min;
				$y_range=~/^(\d+)\d\.?/;
				$y_inc=$1+1;
				$y_max=~/^(\d+)\d\.?/;
				$y_max=$y_max * 10;
			}				
			elsif ($y_max >= 10)
			{
				$y_max=~/^(\d+)\d\.?/; #)
				$y_inc=$1+1;
				$y_max=$y_inc * 10;
			}
			elsif ($y_max >= 1 && $y_max < 10)
			{
				$y_max=~/^(\d)\.?/;
				$y_max=$1+1;
				$y_inc=$y_max * 2;
			}
			elsif ($y_max < 1)
			{
				$y_max=~/^(0\.\d)/;
				$y_max=$1;
				$y_max=($y_max+0.1);
				$y_inc=$y_max * 10;	
				if ($y_inc < 10)
				{
					$y_inc=5;
				}
			}
	
# setting number of markers for the x-axis
			$lengthx=$length+7;
			my $x_mark= $lengthx / 7 ;
			if ($lengthx == 35)
			{
				$lengthx = 30;
				$x_mark = 30;
			}
			$x_inc=$x_mark;

# make uptake_known a percent for the legend, otherwise we assume 90% uptake for that array
			$uptake_known_legend = $uptake_known*100;
			if ($uptake_known_legend !~ /^90$/)
			{
				$uptake_known_legend =~ /^(.+\.?\d?)/;
				$uptake_known_legend ="$1\% (custom)";
			}
			else
			{
				$uptake_known_legend="90\%";
			}		

#... finally...	
			my $mygraph = GD::Graph::area->new(800, 400);
			$mygraph->set(
				x_label     => 'day',
			        y_label     => "ppm $stuff",
			        title       => "Concentrations of $stuff v time using The Estimative Index",
			        line_width  => 2,	
			        dclrs       => ['red', 'pink', 'blue', 'yellow', 'green'],		
				long_ticks  => 1,
			        tick_length => 0,
				x_ticks	    => 0,
				x_label_position => .5,
				y_label_position => .5,
	
				bgclr => 'white',
				transparent => 1,
		
				y_label_skip => 1,	
				y_max_value => $y_max,
				x_max_value => $lengthx,
				y_tick_number => $y_inc,
				x_tick_number => $x_mark,
				x_labels_vertical => 1,
				zero_axis => 0,
				legend_spacing => 2,
				accent_treshold => 100_000,
			) or warn $mygraph->error;

			$mygraph->set_legend_font(GD::gdMediumBoldFont);
			$mygraph->set_legend('no uptake', '25% uptake', '50% uptake', '75% uptake', "$uptake_known_legend uptake");

			$db->do("INSERT INTO graphs (dose,dose_freq,pwc,pwc_freq,dose_pwc,food_ppm,dose_initial,uptake_known,length,regress) VALUES (\'$dose\',\'$dose_freq\',\'$pwc\',\'$pwc_freq\',\'$dose_pwc\',\'$food_ppm\',\'$dose_initial\',\'$uptake_known\',\'$length\',\'$regress\')");
                        if ($db->err()) { die "$DBI::errstr\n"; }
                        $db->commit();
			
			$image=$db->selectrow_array("SELECT last_insert_rowid() FROM graphs");
			
			open(IMG,">images/con_v_time.$image.png") or die $!;
			binmode IMG;
			print IMG $mygraph->plot(\@data)->png;
			close IMG;

# and create a csv of it
			 open (CSV, ">", "images/con_v_time.$image.csv") or die $!;
# CSV header
                        print CSV "day,no_uptake,25%_uptake,50%_uptake,75%_uptake," . $uptake_known_legend . "_uptake,dose_ppm,food_ppm,pwc%\n";

                        for $ref ( 0 .. $#{$data[0]} )
                        {
                                print CSV "$data[0][$ref],$data[1][$ref],$data[2][$ref],$data[3][$ref],$data[4][$ref],$data[5][$ref],$doseday[$ref],$food_ppm,$pwcday[$ref]\n";
                        }

                        close CSV;
		}
		print "<img src='images/con_v_time.$image.png'><br />\n";
		print "<br />\n<br />\n";

# Are we pushing it into a CSV, too?
		if ($csv =~ /true/)
		{
			print "<b>Download the CSV <a href=\"images/con_v_time.$random.csv\" target=\"_new\">here</a>!</b><br /><br />\n";
		}
		if ($save)
		{
			$saved_graphs=$db->selectrow_array("SELECT saved_graphs FROM users WHERE login=\'$login\'");
			$saved_graphs="$saved_graphs $image";
			$db->do("UPDATE users SET saved_graphs=\'$saved_graphs\' WHERE login=\'$login\'");
			$db->commit();
		}
	$db->disconnect();
	
	}	
		
	   
	else
	{
		print "<br />";
		$err=0;
	}
	
}

&printForm($q,$val);
#print $q->end_html;


# The input form.  I really do need more subs...
sub printForm {

	my ($q,$val)=@_;

#	print $q->start_multipart_form();

	print '
<form method="post">
I am adding 
<input type="text" name="dose" size=5 maxlength=4 default='
.$dose.
'> ppm of '
.$stuff.
' <select name="dose_freq">
	<option>1
	<option>2
	<option selected>3
	<option>4
	<option>7
</select>
times a week
<br />';
print "and I'll change";
print '
<input type="text" name="pwc" size=4 maxlength=4> 
% of the water every 
<select name="pwc_freq">
	<option>week.
	<option>two weeks.
	<option>month.
</select>
<br /><br />
How much '
.$stuff.
' would I have each day for the next 
<select name="length">
	<option>month
	<option selected>three months
	<option>six months
	<option>year
</select>
 ?
<br />
<br />
<input type="submit" value="Graph me!">

<br />
<br />
<br />';

if ($login)
{
	print 'Add to my <input type="checkbox" name="save">saved graphs.<br /><br />';
}

# Hiding the Optional block...

print "
Optional 
<input name='advanced' onClick=\"document.getElementById('optional').style.display='block';\" type='checkbox' value='true' />
<div id='optional' style='display:none'>";

print '
	<br />
	Calculate for 
	<input type="text" name="known_uptake" size="5" maxlength="4">
	<input type="radio" name="known_uptake_units">%
	<input type="radio" name="known_uptake_units">ppm
	weekly uptake.
	<br />
	-------
	<br />
	I am starting with 
	<input type="text" name="initial" size=5 maxlength=4>
	 ppm '
	.$stuff.
	'<br />
	-------
	<br/>
	Instead of my regular dose add
	<input type="text" name="dose_pwc" size=5 maxlength=4>
	 ppm of '
	.$stuff.
	' at waterchange.
	<br />
	-------
	<br />
	My tap has 
	<input type="text" name="tap_conc" size=5 maxlength=4>
	 ppm '
	.$stuff.
	'   <br />
	-------
	<br />
	I feed 
	<input type="text" name="food_mg" size=5 maxlength=5>
	 mg of food a week into my
	<input type="text" name="tank" size=6 maxlength=4>
	<input type="radio" name="tank_units" default>gal
	<input type="radio" name="tank_units">L
	 tank.  This food is 
	<input type="radio" name="food_units" default>%
	<input type="radio" name="food_units" default>mg/kg'
	.$stuff.
	'<br />
</div>
<br />';
# and the csv and regression stuff, too..
print "
Hey, nerd
<input name='nerd' onClick=\"document.getElementById('nerd').style.display='block';\" type='checkbox' value='true' /> 
<div id='nerd' style='display:none'>";

	print '
	<br />
	Regress data into a  
	<input type="checkbox" name="regress" value="true">
	 best fit line instead.	
	<br />
	--------
	<br />
	Give me 
	<input type="checkbox" name="CSV" value="true">
	CSV, too, foo.
</div>';
print '
<p>Having trouble calculating Stuff?  Check <a href="http://calc.petalphile.com" target="_blank">this</a> out.</p>
<br />
</form>';


}



	
