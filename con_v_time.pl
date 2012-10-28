#!/usr/bin/perl 

$hi='
 This here ugly script was written by wet@petalphile.com
 so aquatic plant nerds could model levels of various 
 nutrients (Stuff) in aquariums under various levels of 
 plant mass, growth rate, and light (uptake).
 
 you can check out the source on github:
 http://github.com/flores/how-much-junk-in-the-trunk

 suggestions are welcome!';


use CGI::Session;
use CGI::Form;
use CGI ':standard';
use MongoDB;
use MongoDB::OID;
use GD::Graph::area;
use Statistics::OLS;


$q = new CGI::Form;
$c = new CGI;

# did this guy login?
$cookie = $c->cookie(-name => "session");
if ($cookie) {
	CGI::Session->name($cookie);
}
$session = new CGI::Session("driver:File",$cookie,{'Directory'=>"/tmp"}) or die "$!";
$login = $session->param('login');


# are we passing variables from calc.petalphile.com?

my $stuff  = $c->param('stuff');
my $dose   = $c->param('dose');

if ( $stuff =~ /(^\w+$);dose=(.*)/ )
{
	$stuff = "$1";
	$dose = "$2";
}

if ($stuff !~ /^\w+$/)
{
	$stuff = "Stuff";
}
print $q->header();

if ($ENV{'REQUEST_METHOD'} eq 'GET') {

	
	print '<html><head>
<script src="http://code.jquery.com/jquery-1.8.2.min.js" type="text/javascript"></script>
<script src="http://malsup.github.com/jquery.form.js"></script>
<script src="/bootstrap/js/bootstrap.js" type="text/javascript"></script>
<link href="/bootstrap/css/bootstrap.css" rel="stylesheet" type="text/css" />
<link href="/bootstrap/css/bootstrap-responsive.css" rel="stylesheet" type="text/css" />
<script src="/bootstrap/js/bootstrap-collapse.js">
<script src="/bootstrap/js/bootstrap-transition.js">
<script src="http://cdn.petalphile.com/js/ga.js">
';
print "
<script type='text/javascript'>
var options={ 
	target: '#result',
	success: function(){
		return false; 
	},
	error: function(xhr){
		\$('#result').html(xhr.responseText);
	}
};

\$('#eiform').ajaxForm(options);
</script>
";

	print "<title>Concentrations of $stuff vs Time and Plant Uptake using The Estimative Index</title>\n";
	
	print "<! $hi >\n";
	print "</head>";
	
#	print "<p align='right'><font size='2'>\n";
	if ($login)
	{
#		print "Hi $login | <a href='saved_graphs.pl'>view your saved graphs</a> | <a href='logout.pl'>logout</a>";
	}
	else
	{
#		print "<a href='login.pl'>login/register</a> to save your graphs!";
	}
#	print "</font></p>\n";
# alpha marker
        &printForm($q);
        print $q->end_html;


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
	my $graphstyle='fancy';

#	$graphstyle = 'simple';
	

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
	if ( $dose_freq_value=~/1/ && $dose_pwc && $pwc_freq_word=~/^every week$/)
	{
		print "When dosing once a week and weekly water changes you can only use the original dose.  It is the same as your water change dose.<br />\n";
		$err=1;
	}
	if ( $dose_freq_value == 7 && $dose_pwc && $pwc_freq_word=~/^every day$/)
	{
		print "When daily dosing with daily water changes, the water change dose should be empty.  Only use the dosing in the required field.<br />\n";
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
	if ($pwc_freq_word=~/^every week$/)
	{
		$pwc_freq=1;
	}
	elsif ($pwc_freq_word=~/two week/)
	{
		$pwc_freq=2;
	}
	elsif ($pwc_freq_word=~/month/)
	{
		$pwc_freq=4;
	}
	elsif ($pwc_freq_word=~/day/)
	{
		$pwc_freq=1/7;
	}
	elsif ($pwc_freq_word=~/twice a week/)
	{
		$pwc_freq=2/7;
	}
	elsif ($pwc_freq_word=~/three times a week/)
	{
		$pwc_freq=3/7;
	}
	elsif ($pwc_freq_word=~/four times a week/)
	{
		$pwc_freq=4/7;
	}
	
	
	if ($length=~/^month$/)
	{
		$length=28;
	}
	elsif ($length=~/^three months$/)
	{
		$length=91;
	}
	elsif ($length=~/^six months$/)
	{
		$length=182;
	}
	elsif ($length=~/^year$/)
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

# has someone made this exact model before?  
		my $conn = MongoDB::Connection->new(host => 'localhost');
		my $db = $conn->graphdata;
		my $graphs = $db->graphs;
		my $existinggraph=$graphs->find_one( { 
			'dose'		=>	$dose,
			'dose_freq'	=>	$dose_freq,
			'pwc'		=>	$pwc,
			'pwc_freq'	=>	$pwc_freq,
			'dose_pwc'	=>	$dose_pwc,
			'food_ppm'	=>	$food_ppm,
			'dose_initial'	=>	$dose_initial,
			'length'	=>	$length,
			'regress'	=>	$regress,
			'uptake_known'	=>	$uptake_known 
			}, { _id => 1 } );

# yes?  load that image and skip the math.
#		if ($existinggraph != '')
#		{
#			my $image = $existinggraph->to_string;
#		}
#
#		else
#		{
			my @uptake_0=();			
			my @uptake_10=();			
			my @uptake_25=();
			my @uptake_50=();
			my @uptake_75=();
			my @uptake_known=();
			my @doseday=();
			my @pwcday=();
			my @foodppm=();	

# how much Stuff do the plants take up per day at 25%, 50%, 75%, and 90% uptake?		
			my $uptake_rate_25 = ($dose * $dose_freq + $food_ppm) / 7 * 0.25;
			my $uptake_rate_50 = ($dose * $dose_freq + $food_ppm) / 7 * 0.50;
			my $uptake_rate_75 = ($dose * $dose_freq + $food_ppm) / 7 * 0.75;
			my $uptake_rate_90 = ($dose * $dose_freq + $food_ppm) / 7 * $uptake_known;

			push (@uptake_0, $dose_initial);
			push (@uptake_25, $dose_initial);
			push (@uptake_50, $dose_initial);
			push (@uptake_75, $dose_initial);
			push (@uptake_known, $dose_initial);
	
			my @days = ( 1 );
			push(@doseday,$dose_initial);
			push(@pwcday,0);
			my $day=2;
#pie is just a marker that becomes 1 on partial water change (pwc) day
			my $pie=2;

# length is how many days we're building this model...		
			while ($day < ( $length + 1 ) )
			{
				
				my $now_0=@uptake_0[$#uptake_0];
				my $now_25=@uptake_25[$#uptake_25];
				my $now_50=@uptake_50[$#uptake_50];
				my $now_75=@uptake_75[$#uptake_75];
				my $now_90=@uptake_known[$#uptake_known];

# always evenly divisible on pwc day.	
				my $pwc_day = $day / ( 7 * $pwc_freq );
				if ( $pwc_day !~ /\./ && ( $pwc_freq >= 1 || $pwc_freq == 1/7 ) )
				{
					$now_0 = $now_0 * ( (100 - $pwc ) / 100 );
					$now_25 = $now_25 * ( (100 - $pwc ) / 100 );
					$now_50 = $now_50 * ( (100 - $pwc ) / 100 );
					$now_75 = $now_75 * ( (100 - $pwc ) / 100 );
					$now_90 = $now_90 * ( (100 - $pwc ) / 100 );
					push(@pwcday,$pwc);
					$pie=1;
				}
				elsif ( $pie =~ /^4$/ && $pwc_freq == 2/7 )
				{
                                        $now_0 = $now_0 * ( (100 - $pwc ) / 100 );
                                        $now_25 = $now_25 * ( (100 - $pwc ) / 100 );
                                        $now_50 = $now_50 * ( (100 - $pwc ) / 100 );
                                        $now_75 = $now_75 * ( (100 - $pwc ) / 100 );
                                        $now_90 = $now_90 * ( (100 - $pwc ) / 100 );
                                        push(@pwcday,$pwc);
				}
				elsif ( $pie =~ /^(3|5)$/ && $pwc_freq == 3/7 )
				{
        				$now_0 = $now_0 * ( (100 - $pwc ) / 100 );
                                        $now_25 = $now_25 * ( (100 - $pwc ) / 100 );
                                        $now_50 = $now_50 * ( (100 - $pwc ) / 100 );
                                        $now_75 = $now_75 * ( (100 - $pwc ) / 100 );
                                        $now_90 = $now_90 * ( (100 - $pwc ) / 100 );
                                        push(@pwcday,$pwc);
				}
				elsif ( $pie =~ /^7$/ && $pwc_freq =~ /\./ )
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
				elsif ( $pie=~/^(3|5|8)$|10|12|15|17|19|22|24|26/ && ( $dose_freq=~/3|4/ &&  $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}
# ... except for these extra ones when someone doses 4x a week.
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
				elsif ( $pie=~/^4$|11|18|25/ && ($dose_freq=~/2/ && $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}

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

# make uptake_known a percent for the legend, otherwise we assume 90% uptake for that array
			$uptake_known_legend = $uptake_known*100;
			if ($uptake_known_legend !~ /^90$/)
			{
				$uptake_known_legend =~ /^(\d+.?\d?)/;
				$uptake_known_legend ="$1\% (custom)";
			}
			else
			{
				$uptake_known_legend="90\%";
			}		

# simple png graph 
			if ($graphstyle =~ /simple/)
			{
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
	

#... finally...	
				my $mygraph = GD::Graph::area->new(800, 400);
				$mygraph->set(
					x_label     => 'day',
				        y_label     => "ppm $stuff",
				        title       => "Concentrations of Stuff v time and plant uptake using The Estimative Index",
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

				my $graphid = $graphs->insert( {
					'dose'		=>	$dose,
	        	                'dose_freq'	=>	$dose_freq,
					'pwc'		=>	$pwc,
					'pwc_freq'	=>	$pwc_freq,
					'dose_pwc'	=>	$dose_pwc,
					'food_ppm'	=>	$food_ppm,
					'dose_initial'	=>	$dose_initial,
					'length'	=>	$length,
	                        	'regress'	=>	$regress,
	                        	'uptake_known'	=>	$uptake_known
                        	}, { safe => 1 } );
			
				my $image = rand();
				open(IMG,">images/con_v_time.$image.png") or die $!;
				binmode IMG;
				print IMG $mygraph->plot(\@data)->png;
				close IMG;
				print "<img src='images/con_v_time.$image.png'><br />\n";
			}
			else
			{
			print "
			<script type='text/javascript'>
			var chart;
			\$(document).ready(function() {
				chart = new Highcharts.Chart({
					chart: {
						
						renderTo: 'fancy',
						defaultSeriesType: 'areaspline',
						zoomType: 'xy'
					},
					title: {
						text: ''
					},
					subtitle: {
						style: {
							right: '15em',
							top: '20px'
						},
						text: ''
					},
					xAxis: {
						title: {
							text: 'Day',
							align: 'low'
						},
						categories: [
							". join(', ', @days) ."
						],
						tickInterval: 7
					},
					yAxis: {
						title: {
							text: \'ppm $stuff\',
							align: 'low'
						},
						labels: {
							formatter: function() {
								return this.value;
							}
						}
					},
					tooltip: {
						formatter: function() {
				                return this.series.name + ', day '+ this.x +': '+ Math.round(this.y * 10)/10 +'ppm';
						}
					},
					plotOptions: {
						area: {
							fillOpacity: 0.5
						}
					},
					series: [{
						name: 'no plant uptake',
						data: [". join(', ', @uptake_0) ."]
					}, {
						name: '25% uptake',
						data: [". join(', ', @uptake_25) ."]
					}, {
						name: '50% uptake',
						data: [". join(', ', @uptake_50) ."]
					}, {
						name: '75% uptake',
						data: [". join(', ', @uptake_75) ."]
					}, {
						name: '". $uptake_known_legend. " uptake',
						data: [". join(', ', @uptake_known) ."]
					}],
					plotOptions: {
						series: {
							animation: {
								duration: 1000
							}
						}
					},
					credits: {
						enabled: false
					},
					exporting: {
						enabled: false
					}
				});
				
				
			});
				
		</script>";
			}
			

# and create a csv of it
			open (CSV, ">", "images/con_v_time.$image.csv") or die $!;
# CSV header
                        print CSV "day,no_uptake,25%_uptake,50%_uptake,75%_uptake," . $uptake_known_legend . "_uptake,dose_ppm,food_ppm,pwc%\n";

                        for $ref ( 0 .. $#{$data[0]} )
                        {
                                print CSV "$data[0][$ref],$data[1][$ref],$data[2][$ref],$data[3][$ref],$data[4][$ref],$data[5][$ref],$doseday[$ref],$food_ppm,$pwcday[$ref]\n";
                        }

                        close CSV;
#		}

# Are we pushing it into a CSV, too?
		if ($csv =~ /true/)
		{
			print "<b>Download the CSV <a href=\"images/con_v_time.$image.csv\" target=\"_new\">here</a>!</b>\n";
		}
#		if ($save)
#		{
#			$users = $conn->users ;
#			$users->update({"user" => $login}, {'$push' => {'saved_graphs' => $graphid}});
#		}
	}	
		
	   
	else
	{
		print "<br />";
		$err=0;
	}
	
}



 sub printForm {

	my ($q,$val)=@_;
	print '
    <div class="navbar">
      <div class="navbar-inner">
        <button type="button"class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
        </button>
        <a class="brand" href="/">rota.la</a>
        <div class="nav-collapse collapse">
          <ul class="nav">
            <li class="active">
              <a href="/ei">the accumulation of fertilizers vs time and plant uptake</a>
            </li>
            <li class="">
              <a href="/">nutrient calc</a>
            </li>
            <li class="">
              <a href="http://dropcheck.petalphile.com">drop checkers</a>
            </li>
            <li class="">
              <a href="http://glut.petalphile.com">glutaladehyde converter</a>
            </li>
            <li class="">
              <a href="http://y.petalphile.com">wiki</a>
            </li>
            <li class="">
              <a href="http://petalphile.com">about</a>
            </li>
            <li class="">
              <a href="http://y.petalphile.com">contact</a>
            </li>
          </ul>
        </div>
      </div>
    </div>
';



	
#	print "<div id='result'>
#</div>\n
#<div id='loading' style='display: none;'>  
#<img src='ajax-loader.gif'/><br />
#Loading...
#</div>";
	print "
    
<div class='container-fluid'>
  <div class='row'>
    <div class='offset1 span5'>
      <form id='eiform' action='/ei/' method='post' class='form-horizontal' onsubmit='return false;'>
				<div class='accordion' id='accordion'>
	  			<div class='accordion-group'>
	    			<div class='accordion-heading'>
	      			<a class='accordion-toggle' data-toggle='collapse' data-parent='#accordion' href='#required'>
                Required
              </a>
	    			</div>
	    			<div class='accordion-body collapse in' id='required'>
              <div class='control-group'>
                <label class='control-label' for='dose'>Each dose of $stuff is</label>
                <div class='controls'>
                  <input name='dose' type='text' id='dose' default='$dose'/>
										ppm
                </div>
              </div>
              <div class='control-group'>
                <label class='control-label' for='dose_freq'>Doses per week</label>
                <div class='controls'>
                  <select name='dose_freq' id='dose_freq'>
										<option value='1'>daily</option>
										<option value='2'>twice a week</option>
										<option value='3' selected='selected'>every other day</option>
										<option value='7'>weekly</option>
									</select>
                </div>
              </div>
              <div class='control-group'>
                <label class='control-label' for='pwc'>Each water change is</label>
                <div class='controls'>
                  <input name='pwc' type='text' id='pwc' default='50'/>
										%
                </div>
              </div>
              <div class='control-group'>
                <label class='control-label' for='pwc_freq'>Water change schedule</label>
                <div class='controls'>
                  <select name='pwc_freq' id='dose_freq'>
										<option value='every day'>daily</option>
										<option value='twice a week'>twice a week</option>
										<option value='every week' selected='selected'>weekly</option>
										<option value='every month'>monthly</option>
									</select>
                </div>
              </div>
              <div class='control-group'>
                <label class='control-label' for='length'>Project the next</label>
                <div class='controls'>
                  <select name='length' id='length'>
										<option value='month'>month</option>
										<option value='three months' selected='selected'>three months</option>
										<option value='six months'>six months</option>
										<option value='year'>year</option>
									</select>
                </div>
              </div>
						</div>
	  			<div class='accordion-group'>
	    			<div class='accordion-heading'>
	      			<a class='accordion-toggle' data-toggle='collapse' data-parent='#accordion' href='#optional'>
                Optional
              </a>
	    			</div>
	    			<div class='accordion-body collapse' id='optional'>
              <div class='control-group'>
                <label class='control-label' for='known_uptake'>Calculate for known uptake of</label>
                <div class='controls'>
                  <input name='known_uptake' type='text' id='known_uptake'/>
									<label class='radio'>
									  <input name='known_uptake_units' type='radio' value='%' id='known_uptake_units'>
	  								  %
									</label> 
									<label class='radio'>
        					  <input name='known_uptake_units' type='radio' value='ppm' id='known_uptake_units'>
	  								  ppm
        					</label>								
                </div>
              </div>
              <div class='control-group'>
                <label class='control-label' for='initial'>Start with known ppm of $stuff</label>
                <div class='controls'>
                  <input name='initial' type='text' id='initial'/>
										ppm
								</div>
							</div>
              <div class='control-group'>
                <label class='control-label' for='dose_pwc'>Change dose immediately following water change</label>
                <div class='controls'>
                  <input name='dose_pwc' type='text' id='dose_pwc'/>
										ppm
								</div>
							</div>
              <div class='control-group'>
                <label class='control-label' for='tap_conc'>Tap/waterchange water has known concentration of $stuff</label>
                <div class='controls'>
                  <input name='tap_conc' type='text' id='tap_conc'/>
										ppm
								</div>
							</div>
              <div class='control-group'>
                <label class='control-label' for='food_mg'>Calculate for food added</label>
                <div class='controls'>
                  <input name='food_mg' type='text' id='food_mg'/>
                    mg food per week
									<label class='control-label' for='tank'>tank size</label>
                    <input name='tank' type='text' id='food_mg'/>
									<label class='radio'>
									  <input name='tank_units' type='radio' value='gal' id='tank_units'>
	  								  gal
									</label> 
									<label class='radio'>
        					  <input name='tank_units' type='radio' value='L' id='tank_units'>
	  								  L
        					</label>								
                  <label class='control-label' for='food_conc'>This food's concentration of $stuff</label>
                    <input name='food_conc' type='text' id='food_conc'/>
									
									  <input name='' type='radio' value='%' id='tank_units'>
	  								  %
									<label class='radio'>
									  <input name='food_units' type='radio' value='%' id='food_units'>
	  								  %
									</label> 
									<label class='radio'>
        					  <input name='food_units' type='radio' value='mg/kg' id='food_units'>
	  								  mg/kg
        					</label>								
								</div>
							</div>	
						</div>
	  			<div class='accordion-group'>
	    			<div class='accordion-heading'>
	      			<a class='accordion-toggle' data-toggle='collapse' data-parent='#accordion' href='#nerd'>
                Hey nerd
              </a>
	    			</div>
	    			<div class='accordion-body collapse' id='nerd'>
              <div class='control-group'>
								<div class='control'><label>
        					<input type='checkbox' name='regress' value='true'>  Regress data into a best fit line</label>
								</div>
							</div>	
              <div class='control-group'>
								<div class='control'>
        					<input type='checkbox' name='CSV' value='true'>  Make me a CSV too, foo
								</div>
							</div>
						</div>
					</div>	
				</div>
			<input type='submit' name='eiform' value='Chart me!' id='graphbutton'>
			</form>
		</div>
    <div class='offset1 span5'>
			<div id='result'>
			<div id='fancy' name='fancy'>
			</div>
			</div>
			<div id='loading' style='display: none;'>  
				<img src='ajax-loader.gif'/><br />
				Loading...
			</div>
		</div>
	</div>
</div>
";

 }

