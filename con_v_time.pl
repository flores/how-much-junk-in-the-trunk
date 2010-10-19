#!/usr/bin/perl




use CGI::Form;
use CGI ':standard';
use GD::Graph::area;
use Statistics::OLS;

 $q = new CGI::Form;
 
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

 print $q->start_html(-title=>"Concentrations of $stuff vs Time and Plant Uptake using The Estimative Index");

 print "<center>\n";

if ($q->cgi->var('REQUEST_METHOD') eq 'GET') {

	undef($compound);
	undef($doses_wk);
	undef($tank);
	undef($pwc);
	&printForm($q);


 } else {

        $dose=$q->param('dose');
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
	my $regress=$q->param('linear curve fitting');
       	 

# dirty input validation
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
#optional stuff
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
#lets set the dose at pwc if it's not set (just easier later)	
	if ( !$dose_pwc)
	{
		$dose_pwc=$dose;
	}
#let's add whatever is in tap
	if ( !$tap_conc)
	{
		$tap_conc=0;
	}
	
	$dose_pwc=$dose_pwc + ($tap_conc * $pwc / 100);

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
	$op=$q->param('Action');
	if ($op eq "Graph me!" && $err==0) 
	{
		if ($uptake_know!~/\d/)
		{
		
			my @uptake_0=();			
			my @uptake_10=();			
			my @uptake_25=();
			my @uptake_50=();
			my @uptake_75=();
			my @uptake_known=();
			# ima collect CSV data I would like
			my @doseday=();
			my @pwcday=();
			my @foodppm=();	
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
	# animal retention is 10% per PlantBrain's estimate
				$food_ppm = $food_ppm*.9;
				
				$food_ppm=$food_ppm/7;
			}
			else
			{
				$food_ppm=0;
			} 
			
			my $uptake_rate_25 = ($dose * $dose_freq + $food_ppm) / 7 * 0.25;
			my $uptake_rate_50 = ($dose * $dose_freq + $food_ppm) / 7 * 0.50;
			my $uptake_rate_75 = ($dose * $dose_freq + $food_ppm) / 7 * 0.75;
			my $uptake_rate_90 = ($dose * $dose_freq + $food_ppm) / 7 * $uptake_known;


#		print "$uptake_rate_90 is the uptake rate";
			if ($initial)
			{
				$dose_initial=$initial;
			}
			else
			{
				$dose_initial=$dose_pwc;
			}
			push (@uptake_0, $dose_initial);
			push (@uptake_25, $dose_initial);
			push (@uptake_50, $dose_initial);
			push (@uptake_75, $dose_initial);
			push (@uptake_known, $dose_initial);
			
	# frequency of dosing
	#		$dose_freq=8-$dose_freq;
			my (@days);
			push(@days,1);
			push(@doseday,$dose_initial);
			push(@pwcday,0);
			my $day=2;
	#pie is just a marker that becomes 1 on pwc day
			my $pie=2;
	
			
			while ($day < ( $length + 1 ) )
			{
					
				my $now_0=@uptake_0[$#uptake_0];
				my $now_25=@uptake_25[$#uptake_25];
				my $now_50=@uptake_50[$#uptake_50];
				my $now_75=@uptake_75[$#uptake_75];
				my $now_90=@uptake_known[$#uptake_known];
	#always evenly divisible on pwc day.	
				my $pwc_day = $day / ( 7 * $pwc_freq );
	#			print "\n$sweek\n";	
				if ( $pwc_day !~ /\./ )
				{
	#				print "pwc day<br />";
					$now_0 = $now_0 * ( (100 - $pwc ) / 100 );
					$now_25 = $now_25 * ( (100 - $pwc ) / 100 );
					$now_50 = $now_50 * ( (100 - $pwc ) / 100 );
					$now_75 = $now_75 * ( (100 - $pwc ) / 100 );
					$now_90 = $now_90 * ( (100 - $pwc ) / 100 );
					push(@pwcday,$pwc);
					$pie=1;
				}
				else
				{
					push(@pwcday,0);
				}
				if ( ( $dose_freq=~/7/ ) && ( $pie > 1) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
#					print "dose day 1 <br />";
				}
# every possible dosing day in a month, regardless of pwc schedule
				elsif ( $pie=~/^(3|5|8)$|10|12|15|17|19|22|24|26/ && ($dose_freq=~/3|4/ && $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
#					print "dose day 2<br />";
				}
				elsif ( $pie=~/^7$|14|21|28/ && ($dose_freq=~/4/ && $pie > 1) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}
				elsif ( $pie=~/^3$|10|17|24/ && ($dose_freq=~/2/ && $pie > 1 ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}	
				elsif ( $pie =~ /^1$/ )
				{
					$now_0 = $now_0+$dose_pwc;
					$now_25 = $now_25+$dose_pwc;
					$now_50 = $now_50+$dose_pwc;
					$now_75 = $now_75+$dose_pwc;
					$now_90 = $now_90+$dose_pwc;
					push(@doseday,$dose_pwc);
#					print "dose day 3<br />";
				}
				elsif ( $pwc_freq == 4  && ( $dose_freq == 1 && $pie =~ /^(7|14|21)$/ ) )
				{
					$now_0 = $now_0+$dose;
					$now_25 = $now_25+$dose;
					$now_50 = $now_50+$dose;
					$now_75 = $now_75+$dose;
					$now_90 = $now_90+$dose;
					push(@doseday,$dose);
				}
				elsif ( $pwc_freq == 2 && ( $dose_freq == 1 && $pie == 7 ) )
				{
					$now_0 = $now_0+$dose;
                                        $now_25 = $now_25+$dose;
                                        $now_50 = $now_50+$dose;
                                        $now_75 = $now_75+$dose;
					push(@doseday,$dose);
				}
                                         
					
				
				#my $dose_day = $day / $dose_freq;
				#if ($dose_day !~ /\./)
				#{
				#	print "dose day<br />";
				#	$now = $now + $dose;
				#}
	
				else 
				{
					push(@doseday,0);
				}
				$now_0 = $now_0 + $food_ppm;
				$now_25 = $now_25 - $uptake_rate_25 + $food_ppm;
				$now_50 = $now_50 - $uptake_rate_50 + $food_ppm;
				$now_75 = $now_75 - $uptake_rate_75 + $food_ppm;
				$now_90 = $now_90 - $uptake_rate_90 + $food_ppm;
#print "$now_25 ";
	#			print "$now<br />";
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
			# Both the arrays should same number of entries.
			my @data = ();
			push(@data,\@days);
			push(@data,\@uptake_0);
			push(@data,\@uptake_25);
			push(@data,\@uptake_50);
			push(@data,\@uptake_75);
			push(@data,\@uptake_known);
	
	# graph it
#get maximum limit
			my ($y_max,$y_inc);
#        	        if (!$y_max)
#			{	
				foreach my $one (@uptake_0)
                		{
                        		$y_max = $one if $one > $y_max;
					$y_min = $one if $one < $y_min;
                		}
#				$y_max = $y_max - $y_min;
	                	$y_max=$y_max*1.1;
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
#				{
					$y_inc=$1+1;
#					if ($y_inc = 1)
#					{ 
						$y_max=$y_inc * 10;
#						$y_inc=20;
#						$y_inc=10;
#						$y_inc=1; 
#					}
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
#					$y_inc=10;
				}
#				else
#				{
#					$y_=~/
#					if ($y_inc < 10)
#					{
#						$y_inc=10;
#					}
#				}
#				else
#				{
#					$y_inc=5;
#				}
				
#			if ($y_max < 2 && $y_max > 1)
#			{
#				$y_max=2.5;
#			}
#			if ($y_max <= 1)
#			{
#				$y_max=1.5;
#			}
#			}
			
			
			$length=$length+7;
			my $x_mark= $length / 7 ;
#			$x_mark=~/^(\d+)/;
#			$x_mark=$1;
# fix this later
			if ($length == 35)
			{
				$length = 30;
				$x_mark = 30;
			}
			$x_inc=$x_mark;

#make uptake_known a percent for the legend
			$uptake_known = $uptake_known*100;
			if ($uptake_known !~ /^90$/)
			{
				$uptake_known =~ /^(.+\.?\d?)/;
				$uptake_known ="$1\% (custom)";
			}
			else
			{
				$uptake_known="$uptake_known\%";
			}		
	
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
#				y_ticks	    => 10,
				x_label_position => .5,
				y_label_position => .5,
	
				bgclr => 'white',
				transparent => 1,
			
				y_label_skip => 1,	
				y_max_value => $y_max,
				x_max_value => $length,
				y_tick_number => $y_inc,
				x_tick_number => $x_mark,
	#			y_plot_values => 1,
	#			x_plot_values => 7,
				x_labels_vertical => 1,
				zero_axis => 0,
	#			lg_cols => 7,
				legend_spacing => 2,
	
				accent_treshold => 100_000,
	
				) or warn $mygraph->error;
			$mygraph->set_legend_font(GD::gdMediumBoldFont);
			$mygraph->set_legend('no uptake', '25% uptake', '50% uptake', '75% uptake', "$uptake_known uptake");

# cheap and weak random image in case of multiple submits.
			my $random=rand();
	
			open(IMG,">images/con_v_time.$random") or die $!;
			binmode IMG;
			print IMG $mygraph->plot(\@data)->png;
			close IMG;
	
			print "<img src='images/con_v_time.$random'><br />\n";
			print "<br />\n<br />\n";
			if ($csv =~ /true/)
			{
#				#my $file = Text::CSV->new({sep_char => ','});        
				open (CSV, ">", "images/con_v_time.$random.csv") or die $!;  
				print CSV "day,no_uptake,25%_uptake,50%_uptake,75%_uptake," . $uptake_known . "_uptake,dose_ppm,food_ppm,pwc%\n";
				for $ref ( 0 .. $#{$data[0]} ) 
				{
					print CSV "$data[0][$ref],$data[1][$ref],$data[2][$ref],$data[3][$ref],$data[4][$ref],$data[5][$ref],$doseday[$ref],$food_ppm,$pwcday[$ref]\n";
				}
					
#				    else {
#				            print "combine () failed on argument: ";
#	       			          $file->error_input, "\n";
 #  				   }
				close CSV;
#				print "day,ppm_20\%_up,ppempercent_pwc,percent_uptake,day,ppm_stuff<br />\n";
#				for $i ( 0 .. $#data ) {
#				        print "\t elt $i is [ @{$data[$i]} ]<br />\n";
#			        }
			print "<b>Download the CSV <a href=\"images/con_v_time.$random.csv\" target=\"_new\">here</a>!</b><br /><br />\n";
			}
	
		}	
	}
			
	    
	else
	{
#		print "please fix the above and resubmit.<br /><br />\n";
		$err=0;
	}
	&printForm($q,$val);

	print $q->endform;	
	print $q->end_html;
}




 sub printForm {

	my ($q,$val)=@_;

	print $q->start_multipart_form();

	print "\n<center>\n";

	print "I am adding ";
	print $q->textfield( -name=>'dose',-size=>5,-maxlength=>4,-default=>"$dose" );
	print " ppm of $stuff ";
	print $q->popup_menu( -name=>'dose_freq', -values=>['1','2','3','4','7'], -default=>'3');#, -labels=>['week','two weeks','month']);
	print "times a week";
	print "<br />\n";
        print "and<br />\n";
	print "I'll change ";
	print $q->textfield( -name=>'pwc',-size=>4,-maxlength=>4 );
	print " % of the water every ";
	print $q->popup_menu( -name=>'pwc_freq', -values=>['week','two weeks','month'], -default=>'week');#, -labels=>['week.','two weeks.','month.']);
	print "<br />\n";
	print "<br />\n";
	print "How much $stuff would I have every day for the next ";
	print $q->popup_menu( -name=>'length', -values=>['month','three months','six months','year'], -default=>'three months');
	print "?<br />\n";
	print $q->submit( -name=>'Action',-value=>'Graph me!' );
	print "<br />\n";
	print "<br />\n";
	print "<p>Having trouble calculating Stuff?  Check <a href=\"http://calc.petalphile.com\" target='_blank'>this</a> out.</p>";
	print "<br />\n";
	


	print "Optional:<br />\n<br />\n";
	print "Regress data with a ";
        print $q->checkbox( -name=>'linear curve fitting', -value=>'true' );
	print "instead.";
	print "\n<br />-------<br />\n";
	print "Give me a ";
        print $q->checkbox( -name=>'CSV', -value=>'true' );
	print ", too.";
	print "\n<br />-------<br />\n";
	print "I am starting with ";
	print $q->textfield( -name=>'initial',-size=>5,-maxlength=>4 );
	print " ppm $stuff after a waterchange<br />\n";
	print "-------<br />\n";
	print "Instead of my regular dose add ";
        print $q->textfield( -name=>'dose_pwc',-size=>5,-maxlength=>4 );
        print " ppm of $stuff at waterchange.<br />\n";
	print "-------<br />\n";
	print "Calculate for ";
	print $q->textfield( -name=>'known_uptake',-size=>5,-maxlength=>4 );
	print $q->radio_group( -name=>'known_uptake_units', values=>['%','ppm'], -default=>'%');
	print " weekly uptake.<br />";
	print "-------<br />\n";
        print "I feed ";
        print $q->textfield( -name=>'food_mg',-size=>5,-maxlength=>5 );
        print " mg of food a week\n into my ";
        print $q->textfield( -name=>'tank',-size=>6,-maxlength=>4 );
        print $q->radio_group( -name=>'tank_units', values=>['gal','L'], -default=>'gal'); #  " gallons<br /><br />";
	print " tank.\n This food is ";
        print $q->textfield( -name=>'food_conc',-size=>4,-maxlength=>4 );
	print $q->radio_group( -name=>'food_units', values=>['%','mg/kg'], -default=>'%');
	print " $stuff.<br />\n";
	print "-------<br />\n";
	print "My tap has ";
        print $q->textfield( -name=>'tap_conc',-size=>5,-maxlength=>4 );
        print " ppm $stuff.   <br />\n";
#	print "-------<br />\n";
#	print "Set the maximum ppm limit as ";
#	print $q->popup_menu( -name=>'y_max', -values=>['10','25','50','75','100','150','200','250','300','350'] -default=>'0');
#	print " ppm.<br />\n";


 }




