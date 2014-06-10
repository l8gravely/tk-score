#!/usr/bin/perl -w

use strict;
use Tk;
use Tk::DialogBox;
use Tk::BrowseEntry;
use Tk::FileSelect;
use YAML qw(DumpFile LoadFile);
use IO::Handle;

my $game_file = "DSL-2012-Outdoor.tks";
my $rpt_file = $game_file;
$rpt_file =~ s/\.tks$/\.rpt/;

my $NeedSave = 0;

# Flush all output right away...
$|=1;

#---------------------------------------------------------------------
my @scores = ( '','F',0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
my $homeforfeit= 0;
my $homecoed = 'no';
my $homescore = " ";

my $notokcolor = 'darkgrey';
my $okcolor    = 'lightgreen';


# This should be stored in a YAML file.
my %teams = ( 1 => 'Bollocks',
			  2 => 'New Order',
			  3 => 'Coasters',
			  4 => 'White Fish',
			  5 => 'Wild Geese',
			  6 => 'Rage',
			  7 => 'Physical Graffiti',
			  8 => 'Hooligans',
  );

# This should be stored in a YAML file.
my %lining = ( 1  => 1,
			   2  => 5, 3  => 5,
			   4  => 3, 5  => 3,
			   6  => 4, 7  => 4,
			   8  => 6, 9  => 6,
			   10 => 8, 11 => 8,
			   12 => 7, 13 => 7,
			   14 => 2, 15 => 2,
			   16 => "tbd", 17 => "tdb",
  );

my %sched_eight_teams = ( );
my %sched_nine_teams = ( );

#---------------------------------------------------------------------
# Don't be stupid, just pre-figure out an 8 or 9 team season schedule
# and stick with it, making changes as needed.  Sigh... 
#
sub init_season {
  my $n_teams;
  my $n_playoffs = shift;
  my $n_makeups = shift;
  my $overlap_m_p = shift;
  my $n_preseason = shift;
  my $lining = shift;

  print "init_season($n_teams,$n_playoffs,$n_makeups,$overlap_m_p,$n_preseason,$lining)\n";

  my @m;
  
  my $n_weeks = ($n_teams - 1) * 2;
  # Odd number of teams requires bye weeks
  my $need_byes = $n_teams % 2;

  my $total_weeks = $n_weeks + $n_playoffs + $n_makeups - $overlap_m_p;

  print "Num weeks of games = $n_weeks\n";
  print "Total weeks = $total_weeks\n";

  for (my $week = 1; $week <= ($n_weeks + $n_playoffs); $week++) {
	print "  $week\n";
  }
  return @m;
}

# This should be stored in a YAML file.
my @matches = ( 
  { Week => 1,
	Date => '04/24/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 1,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 1,
	Date => '04/24/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 3,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 1,
	Date => '04/24/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 5,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 1,
	Date => '04/24/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 7,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 2,
	Date => '05/01/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 5,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 2,
	Date => '05/01/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 6,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 2,
	Date => '05/01/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 1,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 2,
	Date => '05/01/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 2,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 3,
	Date => '05/08/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 4,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 3,
	Date => '05/08/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 1,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 3,
	Date => '05/08/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 2,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 3,
	Date => '05/08/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 3,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 4,
	Date => '05/15/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 2,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 4,
	Date => '05/15/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 3,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 4,
	Date => '05/15/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 4,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 4,
	Date => '05/15/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 1,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 5,
	Date => '05/22/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 3,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 5,
	Date => '05/22/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 2,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 5,
	Date => '05/22/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 1,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 5,
	Date => '05/22/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 4,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 6,
	Date => '05/29/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 1,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 6,
	Date => '05/29/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 4,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
  },
  { Week => 6,
	Date => '05/29/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 2,
	Away => 8,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 6,
	Date => '05/29/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 3,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 7,
	Date => '06/05/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 4,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 7,
	Date => '06/05/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 7,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 7,
	Date => '06/05/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 8,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 7,
	Date => '06/05/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 3,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 8,
	Date => '06/12/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 6,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
 },
  { Week => 8,
	Date => '06/12/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 4,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 8,
	Date => '06/12/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 2,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 8,
	Date => '06/12/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 8,
	Away => 7,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 9,
	Date => '06/19/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 7,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 9,
	Date => '06/19/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 8,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 9,
	Date => '06/19/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 3,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 9,
	Date => '06/12/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 4,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 10,
	Date => '06/26/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 8,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 10,
	Date => '06/26/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 5,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 10,
	Date => '06/26/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 7,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 10,
	Date => '06/26/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 6,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 11,
	Date => '07/03/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 8,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 11,
	Date => '07/03/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 5,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 11,
	Date => '07/03/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 7,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 11,
	Date => '07/03/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 6,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 12,
	Date => '07/10/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 6,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 12,
	Date => '07/10/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 7,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 12,
	Date => '07/10/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 5,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 12,
	Date => '07/10/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 8,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 13,
	Date => '07/17/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 6,
	Away => 4,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 13,
	Date => '07/17/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 7,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 13,
	Date => '07/17/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 8,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 13,
	Date => '07/17/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 5,
	Away => 3,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  { Week => 14,
	Date => '07/24/2012',
	Time => '6pm',
	Field => 'Field 1',
	Home => 3,
	Away => 2,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 14,
	Date => '07/24/2012',
	Time => '6pm',
	Field => 'Field 2',
	Home => 8,
	Away => 5,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 14,
	Date => '07/24/2012',
	Time => '7pm',
	Field => 'Field 1',
	Home => 7,
	Away => 6,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  { Week => 14,
	Date => '07/24/2012',
	Time => '7pm',
	Field => 'Field 2',
	Home => 4,
	Away => 1,
	HomeScore => "",
	HomeCoed => 0,
	HomePoints => 0,
	AwayScore => "",
	AwayCoed => 0,
	AwayPoints => 0,
	Complete => 0,
  },
  
  );

my $numteams = 8;
my $numweeks = 16;
my $week = 1;
my $curweek = 0;
my $weekdate= "";
my @weeks;
my $matches_per_week = 4;

for (my $w=1; $w <= $numweeks; $w++) {
  push @weeks, $w;
}

# Per-team standings.  Re-calculated depending on the week showing.
my $cnt = 1;
my %curmatch;
for (my $m=1; $m <= $matches_per_week; $m++) {
  $curmatch{$m}->{HomeScore} = "";
  $curmatch{$m}->{HomeCoed} = 0;
  $curmatch{$m}->{HomePoints} = "";
  $curmatch{$m}->{AwayScore} = "";
  $curmatch{$m}->{AwayCoed} = 0;
  $curmatch{$m}->{AwayPoints} = "";
  $curmatch{$m}->{PointsLabels} = ();
}

my %standings;

#---------------------------------------------------------------------
# Sort the %standings array (see zero_standings for format) by RANK,
# W, L, T and maybe more...

#---------------------------------------------------------------------
sub byweektimefield {
  $a->{Week} <=> $b->{Week} ||
    $a->{Time} cmp $b->{Time} ||
	$a->{Field} cmp $b->{Field};
}

#---------------------------------------------------------------------
sub updateweekdates {
  my $old = shift;
  my $new = shift;

  print "updateweekdates($old,$new)\n";

  my %dates;
  my $found=0;
  foreach my $match (sort byweektimefield @matches) {
	if ($match->{"Date"} eq $old) {
	  $match->{"Date"} = "$new ($old)";
	  print "  match->{Date} = ", $match->{Date}, "\n";
	  $found++;
	}
  }
  return $found;
}

#---------------------------------------------------------------------
sub getweekdates {
  my $w = shift;

  foreach my $match (sort byweektimefield @matches) {
	if ($match->{"Week"} == $w) {
	  my $d = $match->{Date};
	  #print "Week = $w, Date = $d\n";
	  return $d;
	}
  }
}

#---------------------------------------------------------------------
# Change the date of a match

sub match_reschedule {
  my $top = shift;
  my $w = shift;

  print "match_reschedule($w)\n";
  
  my $old_date = &getweekdates($w);
  my $new_date = "";

  my $dialog = $top->DialogBox(-title => "Reschedule Match Date",
							   -buttons => [ 'Ok', 'Cancel' ],
							   -default_button => 'Ok');
  $dialog->add('Label', -text => "Old Date: $old_date", -width => 10,)->pack;
  $dialog->add('LabEntry', -textvariable => \$new_date, -width => 10, 
			   -label => 'New Date (MM/DD/YYYY)', 
			   -labelPack => [-side => 'left'])->pack;

  my $ok = 1;
  while ($ok) {
	my $answer = $dialog->Show( );
	
	if ($answer eq "Ok") {
	  print "New Date = $new_date\n";
	  if ($new_date =~ m/^\d\d\/\d\d\/\d\d\d\d$/) {
		$ok--;
		my $num_matches = &updateweekdates($old_date,$new_date);
	  }
	  else {
		$top->messageBox(
		  -title => "Error!  Bad Date format.",
		  -message => "Error!  Bad Date format, please use MM/DD/YYYY.",
		  -type => 'Ok',
		  );
	  }
	}
	elsif ($answer eq "Cancel") {
	  print "No update made.\n";
	}
  }
}

#---------------------------------------------------------------------
sub mk_results_rpt {
  my $w = shift;
  my $fh = shift;
  
  print "mk_results_rpt($w,FH)\n";

  my $d = getweekdates($w);
  my ($h, $hc, $hs);
  my ($a, $ac, $as);

  my $ws = "$w ($d)";

format RESULTS_TOP =

  Results:  Week @<<<<<<<<<<<<<<<<<<<<<<<
                $ws

.

format RESULTS =
      @<<<<<<<<<<<<<<<<<  @>  @<<<   vs  @<<<<<<<<<<<<<<<<<  @>  @<<<
	  $h,                 $hs,$hc,       $a,                 $as,$ac
.
  

  $fh->format_name("RESULTS");
  $fh->format_top_name("RESULTS_TOP");
  $fh->autoflush(1);
  $fh->format_lines_left(0);

  for (my $i=1; $i <= $matches_per_week; $i++) {
    $h = $curmatch{$i}->{"HomeName"} . ":";
    $hs = $curmatch{$i}->{"HomeScore"};
    $hc = $curmatch{$i}->{"HomeCoed"} ? "(C)" : "(no)";
    
    $a = $curmatch{$i}->{"AwayName"} . ":";
    $as = $curmatch{$i}->{"AwayScore"};
    $ac = $curmatch{$i}->{"AwayCoed"} ? "(C)" : "(no)";
    write $fh;
  }
}

#---------------------------------------------------------------------
sub mk_standings_rpt {
  my $week = shift;
  my $fh = shift;

  print "mk_standings_rpt($week,FH)\n";

  my ($n, $team, $w, $t, $l, $f, $c, $gf, $ga, $pts, $d);

  $d = "$week, (" . &getweekdates($week) . ")";

format STANDINGS_TOP =

  Standings after Week @<<<<<<<<<<<<<<<<
                       $d                       

      # Team               W   T   L   F   C   GF   GA  Pts
      - ----------------- --- --- --- --- --- ---  ---  ----
.

format STANDINGS =
      @ @<<<<<<<<<<<<<<<< @>> @>> @>> @>> @>> @>>  @>>  @>>>
    $n,$team,           $w, $t, $l, $f, $c, $gf, $ga, $pts
.

  $fh->format_name("STANDINGS");
  $fh->format_top_name("STANDINGS_TOP");
  $fh->autoflush(1);
  $fh->format_lines_left(0);

  &update_standings($week);
  for (my $i = 1; $i <= $numteams; $i++) {
	$n    = $standings{$i}->{TEAMNUM};
	$team = $standings{$i}->{TEAM};
	$w    = $standings{$i}->{W};
	$t    = $standings{$i}->{T};
	$l    = $standings{$i}->{L};
	$f    = $standings{$i}->{F};
	$c    = $standings{$i}->{C};
	$gf   = $standings{$i}->{GF};
	$ga   = $standings{$i}->{GA};
	$pts  = $standings{$i}->{PTS};

	write $fh;
  }  
}

#---------------------------------------------------------------------
sub mk_notes {
  my $fh = shift;

  print "mk_notes(FH)\n";

  print $fh "\n\n";
  print $fh "----------------------------\n";
  print $fh "Weekly Notes go here...\n";
  print $fh "----------------------------\n";
  print $fh "\n";
}

#---------------------------------------------------------------------
sub mk_schedule_rpt {
  my $week = shift;
  my $fh = shift;

  print "mk_schedule_rpt($week,FH)\n";

  $week++;
  my $nextweek = $week + 1;
  my $prevtime = "";
  my $prevfield = "";

  my ($time, $field, $home,$away);

  my $weekdate = &getweekdates($week);
  my $nextweekdate = &getweekdates($nextweek);
  my $weekstr = "$teams{$lining{$week}} ($weekdate)";
  my $nextweekstr = "$teams{$lining{$nextweek}} ($nextweekdate)";

format SCHEDULE_TOP = 

  Schedule: @<<<<<<<<<<<<<<
             $weekdate

      Time    Field      Home                   Away
      ------  -------    ------------------     ------------------
.

format SCHEDULE =
      @<<<<<  @<<<<<<    @<<<<<<<<<<<<<<<<<     @<<<<<<<<<<<<<<<<<
      $time,  $field,    $home,                 $away
.

  $fh->format_name("SCHEDULE");
  $fh->format_top_name("SCHEDULE_TOP");
  $fh->autoflush(1);
  $fh->format_lines_left(0);

  foreach my $m (sort byweektimefield @matches) {
	if ($m->{"Week"} == $week) {
	  $time = $m->{"Time"};
	  $field = $m->{"Field"};
	  $home = $teams{$m->{"Home"}};
	  $away = $teams{$m->{"Away"}};
	  write $fh;
	}
  }

format LINING_TOP =
.

format LINING =
  Lining:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
           $weekstr;
           @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
           $nextweekstr


.

  $fh->format_name("LINING");
  $fh->format_top_name("LINING_TOP");
  $fh->autoflush(1);
  $fh->format_lines_left(0);
  write $fh;

}

#---------------------------------------------------------------------
sub mk_key_rpt {
  my $fh = shift;
  print "mk_key_rpt(FH)\n";

  print $fh "\n";
  print $fh "Key\n";
  print $fh "------------\n";
  print $fh "#  - Team Number on Schedule\n";
  print $fh "W  - Wins\n";
  print $fh "T  - Ties\n";
  print $fh "L  - Losses\n";
  print $fh "C  - Coed Games\n";
  print $fh "Fo - Forfeits\n";
  print $fh "GF - Points For\n";
  print $fh "GA - Points Against\n";
  print $fh "Pts - Points for Standings\n";
  print $fh "\n";
  print $fh "See rules for how standings are calculated.\n";
  print $fh "\n";

}

#---------------------------------------------------------------------
# Make the weekly report.

sub make_report {
  my $rptfile = shift;

  if (!open(RPT, ">$rptfile")) {
    warn "Error writing week $curweek report to $rptfile: $!\n";
  }  
  else {
    &mk_results_rpt($curweek,\*RPT);
    &mk_standings_rpt($curweek,\*RPT);
    &mk_notes(\*RPT);
    &mk_schedule_rpt($curweek,\*RPT);
    &mk_key_rpt(\*RPT);
    close RPT;

    print "\nWrote game report to $rptfile.\n";
  }
}
   
#---------------------------------------------------------------------
sub init_game_file {
  my $top = shift;

  print "init_game_file()\n";
  print "  Not implemented yet.\n";
}

#---------------------------------------------------------------------
sub init_standings {
  my $top = shift;

  print "init_standings()\n";

  &zero_standings(\%standings);
  
  my $f = $top->Frame;
  # Header
  my $ff = $f->Frame(-pady => 10, -border => 1);
  $ff->Label(-text => "#", -width => 2)->pack(-side => 'left');
  $ff->Label(-text => "Team", -width => 20, -anchor => 'w')->pack(-side => 'left');
  $ff->Label(-text => " W ", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " T ", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " L ", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " F ", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " C ", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " GF", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => " GA", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => "PTS", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => "Rank", -width => 4)->pack(-side => 'left');
  $ff->pack(-side => 'top', -fill => 'x');

  foreach (my $x=1; $x <= $numteams; $x++) {
    my $ff = $f->Frame()->pack(-side => 'top', -fill => 'x');

    $ff->Label(-text => $x, -width => 2)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{TEAM}, -width => 20)->pack(-side => 'left');
	$standings{$x}->{TEAM} = $teams{$x};
    $ff->Label(-textvariable => \$standings{$x}->{W}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{T}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{L}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{F}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{C}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{GF}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{GA}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{PTS}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{RANK}, -width => 4)->pack(-side => 'left');
    $ff->pack(-side => 'top', -fill => 'x');
  }
  $f->pack(-side => 'top', -fill => 'x');
 }

#---------------------------------------------------------------------
# Used to both initialize and reset standings when updated.
sub zero_standings {

  if (@_) {
	my $ref = shift;
	for (my $t=1; $t <= $numteams; $t++) {
	  foreach my $k (qw( W L T F C PTS GF GA RANK)) {
		$$ref{$t}->{$k} = 0;
	  }
	}
  }
  else {
	for (my $t=1; $t <= $numteams; $t++) {
	  foreach my $k (qw( W L T F C PTS GF GA RANK)) {
		$standings{$t}->{$k} = 0;
	  }
	}
  }	
}

#---------------------------------------------------------------------
sub update_standings {

  my $week = shift;

  my %tmp;
  print "\nupdate_standings($week)\n";

  # Zero out the standings first
  &zero_standings(\%standings);
  &zero_standings(\%tmp);

  # Save the current week data back to @matches
  &save_curmatch($curweek);

  # Now go through all matches and figure out standings.
  foreach my $m (sort byweektimefield @matches) {
    my $matchweek = $m->{"Week"};
    #print "Match week: $matchweek, Curweek: $curweek\n";
    if ($matchweek <= $curweek) {
      my $c = $m->{"Complete"};
      #print "Summing week $week (Complete = $c)\n";
      
      if ($c) {
	my $h = $m->{"Home"};
	my $a = $m->{"Away"};
	
	#print " Match Complete:  H: $h, A: $a\n";
	
	if ($m->{HomeScore} eq "F" && $m->{AwayScore} eq "F") {
	  #print "  Double Forfeit\n";
	  $tmp{$h}->{F}++;
	  $tmp{$a}->{F}++;
	}
	elsif ($m->{HomeScore} eq "F") {
	  #print "  Home forfeit\n";
	  $tmp{$h}->{F}++;
	  $tmp{$a}->{W}++;
	  $tmp{$a}->{GF} += 5;
	} 
	elsif ($m->{AwayScore} eq "F") {
	  #print "  Away Forfeit\n";
	  $tmp{$a}->{F}++;
	  $tmp{$h}->{W}++;
	  $tmp{$h}->{GF} += 5;
	}
	else {
	  $tmp{$h}->{GF} += $m->{HomeScore};
	  $tmp{$a}->{GA} += $m->{HomeScore};
	  $tmp{$h}->{GA} += $m->{AwayScore};
	  $tmp{$a}->{GF} += $m->{AwayScore};
	  if ($m->{HomeScore} < $m->{AwayScore}) {
	    $tmp{$h}->{L}++;
	    $tmp{$a}->{W}++;
	  }
	  elsif ($m->{HomeScore} == $m->{AwayScore}) {
	    $tmp{$h}->{T}++;
	    $tmp{$a}->{T}++;
	  }
	  elsif ($m->{HomeScore} > $m->{AwayScore}) {
	    $tmp{$h}->{W}++;
	    $tmp{$a}->{L}++;
	  }
	}
	
	$tmp{$h}->{C} += $m->{HomeCoed};
	$tmp{$a}->{C} += $m->{AwayCoed};
	
	#print "  HomePoints = $m->{HomePoints}\n";
	$tmp{$h}->{PTS} += $m->{HomePoints};
	$tmp{$a}->{PTS} += $m->{AwayPoints};
      }
    }
  }
  
  # Now sort %tmp and update %standings
  
  my $x = 1;
  foreach my $idx (sort {
    $tmp{$b}->{PTS} <=> $tmp{$a}->{PTS} 
      ||
	$tmp{$b}->{W} <=> $tmp{$a}->{W}
	  ||
	    $tmp{$b}->{L} <=> $tmp{$a}->{L}
	      ||
		$tmp{$b}->{T} <=> $tmp{$a}->{T}
		  ||
		    ($tmp{$b}->{GF} - $tmp{$b}->{GA}) <=> ($tmp{$a}->{GF} - $tmp{$a}->{GA});
  } keys %tmp) {
    #print "$idx  $teams{$idx}   $tmp{$idx}->{PTS}\n";
    foreach my $k (qw( W L T F C PTS GF GA RANK)) {
      $standings{$x}->{$k} = $tmp{$idx}->{$k};
    }
    $standings{$x}->{TEAMNUM} = $idx;
    $standings{$x}->{TEAM} = $teams{$idx};
    $x++;
  }
}

#---------------------------------------------------------------------
# Save the current info in %curmatch back to the @match array.
sub save_curmatch {
  my $w = shift;

  # Save current week data....
  my $idx = 1;
  print "save_curmatch($w)\n";
  foreach my $m (sort byweektimefield @matches) {
    if ($m->{"Week"} == $w) {
      $m->{"HomePoints"} = $curmatch{$idx}->{"HomePoints"};
      $m->{"HomeScore"} = $curmatch{$idx}->{"HomeScore"};
      $m->{"HomeCoed"} = $curmatch{$idx}->{"HomeCoed"};
      #$curmatch{$idx}->{HomeScore} = "";
      
      $m->{"AwayPoints"} = $curmatch{$idx}->{"AwayPoints"};
      $m->{"AwayScore"} = $curmatch{$idx}->{"AwayScore"};
      $m->{"AwayCoed"} = $curmatch{$idx}->{"AwayCoed"};
      
      $m->{"Complete"} = $curmatch{$idx}->{"Complete"};
      $idx++;
    }
  }
}

#---------------------------------------------------------------------
sub clear_match_display {

  # Empty the Home and Away columns first, we have four matches per-week.
  for (my $i=1; $i <= $matches_per_week; $i++) {
	$curmatch{$i}->{"HomePoints"} = 0;
	$curmatch{$i}->{"HomeScore"} = 0;
	$curmatch{$i}->{"HomeCoed"} = 0;
	$curmatch{$i}->{"HomeName"} = "";
	$curmatch{$i}->{"AwayPoints"} = 0;
	$curmatch{$i}->{"AwayScore"} = 0;
	$curmatch{$i}->{"AwayCoed"} = 0;
	$curmatch{$i}->{"AwayName"} = "";

	$curmatch{$i}->{"Time"} = "";
	$curmatch{$i}->{"Field"} = "";
	$curmatch{$i}->{"Complete"} = 0;
	&chgcolor($notokcolor,$i);
  }
}

#---------------------------------------------------------------------
# Load the current match with data week $week

sub load_curmatch {
  my $week = shift;
  
  &clear_match_display;

# Fill in the $curmatches with the proper match info
  my $curidx = 1;
  foreach my $m (sort byweektimefield @matches) {
    if ($m->{"Week"} == $week) {
      $curmatch{$curidx}->{"HomePoints"} = $m->{"HomePoints"};
      $curmatch{$curidx}->{"HomeScore"} = $m->{"HomeScore"};
      $curmatch{$curidx}->{"HomeCoed"} = $m->{"HomeCoed"};
      $curmatch{$curidx}->{"HomeName"} = $teams{$m->{"Home"}};
      
      $curmatch{$curidx}->{"AwayPoints"} = $m->{"AwayPoints"};
      $curmatch{$curidx}->{"AwayScore"} = $m->{"AwayScore"};
      $curmatch{$curidx}->{"AwayCoed"} = $m->{"AwayCoed"};
      $curmatch{$curidx}->{"AwayName"} = $teams{$m->{"Away"}};
      
      $curmatch{$curidx}->{"Time"} = $m->{"Time"};
      $curmatch{$curidx}->{"Field"} = $m->{"Field"};
      $curmatch{$curidx}->{"Complete"} = $m->{"Complete"};
      
      if ($m->{"Complete"}) {
		&chgcolor($okcolor,$curidx);
      } 
      else {
		&chgcolor($notokcolor,$curidx);
      }
      $curidx++;
    }
  }
}

#---------------------------------------------------------------------
sub update_scores {
  my $week = shift;

  print "\nupdate_scores($week)\n";
    
  if ($curweek != $week) {
    my $curidx;
    $weekdate = join("-", &getweekdates($week));
    
    &save_curmatch($curweek);
    
    &load_curmatch($week);
    # Reset the Current Week finally.
    $curweek = $week;
    &update_standings($curweek);
  }
}

#---------------------------------------------------------------------
sub init_scores {
  my $top = shift;
  my $week = shift;
  
  my $header = $top->Frame;
  my $hf = $top->Frame;
  my $scoreframe = $top->Frame;
  
  # Week dropdown and dates
  $header->BrowseEntry(-label => 'Week:', -variable => \$week, 
		       -width => 2,
		       -choices => \@weeks,
		       -command => sub { &update_scores($week); },
		      )->pack(-side => 'left');
  
  $weekdate=join("-",&getweekdates($week));
  print "Weekdate = $weekdate\n";
  $header->Label(-text => "Date: ", -width => 30, 
		 -anchor => 'e')->pack(-side=>'left');
  $header->Label(-textvariable => \$weekdate,
		 -width => 12)->pack(-side=>'left');
  
  $header->pack(-side => 'top', -fill => 'x');
  
  # Headers
  
  $hf->Label(-text => "Time", -width => 6)->pack(-side => 'left');
  $hf->Label(-text => "Field", -width => 8)->pack(-side => 'left');
  $hf->Label(-text => "Home", -anchor => 'w', -width => 20)->pack(-side => 'left');
  $hf->Label(-text => "Score", -width => 10)->pack(-side => 'left');
  $hf->Label(-text => "Coed", -width => 4)->pack(-side => 'left');
  $hf->Label(-text => "Points", -width => 7)->pack(-side => 'left');
  
  $hf->Label(-text => "vs", -width => 8)->pack(-side => 'left');
  
  $hf->Label(-text => "Away", -anchor => 'w', -width => 20)->pack(-side => 'left');
  $hf->Label(-text => "Score",-width=>10)->pack(-side => 'left');
  $hf->Label(-text => "Coed",-width=>4)->pack(-side => 'left');
  $hf->Label(-text => "Points",-width=>6)->pack(-side => 'left');
  $hf->pack(-side => 'top', -fill => 'x');
  
  # Now create the pairs of games, currently maxes out at 4:
  
  foreach (my $m=1; $m <= $matches_per_week; $m++) {
    my $f = $top->Frame;
	my $w;
	
    $f->Label(-textvariable => \$curmatch{$m}->{"Time"}, -width => 6)->pack(-side => 'left');
    $f->Label(-textvariable => \$curmatch{$m}->{"Field"}, -width => 8)->pack(-side => 'left');
    $f->Label(-textvariable => \$curmatch{$m}->{HomeName}, -anchor =>
			  'w', -width => 20)->pack(-side => 'left');
    $f->BrowseEntry(-label => 'Score',
					-variable => \$curmatch{$m}->{"HomeScore"},	
					-width => 3,
					-listwidth => 20,
					-choices => \@scores,
					-browsecmd => [ \&computepoints, $m,"Home" ],
	  )->pack(-side => 'left');
    $f->Checkbutton( -variable => \$curmatch{$m}->{"HomeCoed"},
					 -command => [ \&computepoints, $m,"Home" ],
	  )->pack(-side => 'left');
    
    $w = $f->Label(-textvariable => \$curmatch{$m}->{"HomePoints"},
				   -background => $notokcolor,
				   -width => 6,
	  )->pack(-side => 'left');
    push @{$curmatch{$m}->{PointsLabels}}, $w;
    
    $f->Label(-text => "vs", -width => 8)->pack(-side => 'left');
    
    $f->Label(-textvariable => \$curmatch{$m}->{"AwayName"}, 
			  -anchor => 'w', -width => 20)->pack(-side => 'left');
	$f->BrowseEntry(-label => 'Score',
					-variable => \$curmatch{$m}->{"AwayScore"},	
					-width => 3,
					-listwidth => 20,
					-choices => \@scores,
					-browsecmd => [ \&computepoints, $m,"Home" ],
	  )->pack(-side => 'left');
    $f->Checkbutton( -variable => \$curmatch{$m}->{"AwayCoed"},
					 -command => [ \&computepoints, $m,"Home" ],
	  )->pack(-side => 'left');
    
    $w = $f->Label(-textvariable => \$curmatch{$m}->{"AwayPoints"},
				   -background => $notokcolor,-width => 6,
	  )->pack(-side => 'left');
    $f->pack(-side => 'top',-fill => 'x');
    push @{$curmatch{$m}->{PointsLabels}}, $w;
  }
  $top->pack(-side => 'top', -fill => 'x');
}


#---------------------------------------------------------------------
sub chgcolor {
  my $c = shift;
  my $i = shift;

  foreach my $w (@{$curmatch{$i}->{"PointsLabels"}}) {
    $w->configure(-background => "$c");
  }
}

#---------------------------------------------------------------------
sub load_game_file {
  my $top = shift;
  my $game_file = shift;

  print "load_game_file($game_file)\n";

  my $fs = $top->FileSelect(-directory => ".",
							-filter => "*.tks",
							-initialfile => $game_file,
	);

  $fs->geometry("600x400");

  my $gf = $fs->Show;

  if ($gf ne "") {
	print "  Reading from: $gf\n"
	my ($teamref,$matchref,$standingsref) = LoadFile($gf);

	# Reload Teams
	foreach (keys %$teamref) {
	  $teams{$_} = $$teamref{$_};
	  print "  $_ = $$teamref{$_}\n";
	}
	
	# Reload Matches
	@matches = @$matchref;
	
	&load_curmatch(1);
	&update_standings(1);
  }
}

#---------------------------------------------------------------------
sub save_game_file {
  my $top = shift;
  my $gf = shift;
  my $teamref = shift;
  my $matchref = shift;
  my $standingsref = shift;

  print "DumpFile($gf, .... )\n";
  DumpFile($gf,$teamref,$matchref,$standingsref);
}

#---------------------------------------------------------------------
sub save_game_file_as {
  my $top = shift;
  my $gf = shift;
  my $teamref = shift;
  my $matchref = shift;
  my $standingsref = shift;

  my $fs = $top->FileSelect(-directory => '.',
							-filter => "*.tks",
							-initialfile => $game_file,
	);
  $fs->geometry("600x400");
  my $savefile = "";
  $savefile = $fs->Show;
  
  if ($savefile ne "") {
	print "DumpFile($savefile, .... )\n";
	DumpFile($savefile,$teamref,$matchref,$standingsref);
  }
  else {
	print "DumpFile($gf, .... )\n";
	DumpFile($gf,$teamref,$matchref,$standingsref);
  }
}

#---------------------------------------------------------------------
sub load_config {


}

#---------------------------------------------------------------------
sub computepoints {

  my $idx = shift;
  my $us = shift;

  print "computepoints($idx,$us)\n";
  my ($ourscore,$ourcoed,$ourpts,$them,$theirscore,$theircoed);

  #print "scoring the match...\n";
  my $hs = $curmatch{$idx}->{"HomeScore"};
  my $hc = $curmatch{$idx}->{"HomeCoed"};
  my $as = $curmatch{$idx}->{"AwayScore"};
  my $ac = $curmatch{$idx}->{"AwayCoed"};
  
  #print "Scores:  $hs ($hc) : $as ($ac)\n";
  
  # Now we score the damn thing, big ugly state table...

  # Check for two empty scores, or one numeric and one empty
  if ($hs eq "" and $as eq "")  {
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"AwayPoints"} = 0;
	$curmatch{$idx}->{"Complete"} = 0;
    &chgcolor($notokcolor,$idx);
  }
  # Double Forfeit = no points for anyone.
  elsif ($hs eq "F" and $as eq "F") {
	#print "Double Forfeit\n";
	$curmatch{$idx}->{"HomePoints"} = 0;
	$curmatch{$idx}->{"HomeCoed"} = 0;
	$curmatch{$idx}->{"AwayPoints"} = 0;
	$curmatch{$idx}->{"AwayCoed"} = 0;
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
  elsif ($hs eq "F" and $as =~ m/^$|\d+/) {
	#print "Home Forfeit.\n";
	$curmatch{$idx}->{"HomePoints"} = 0;
	$curmatch{$idx}->{"HomeCoed"} = 0;
	$curmatch{$idx}->{"AwayScore"} = "";
	$curmatch{$idx}->{"AwayPoints"} = 6 + $curmatch{$idx}->{"AwayCoed"};
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
  elsif ($as eq "F" and $hs =~ m/^$|\d+/) {
	#print "Away Forfeit.\n";
	$curmatch{$idx}->{"HomePoints"} = 6 + $curmatch{$idx}->{"HomeCoed"};
	$curmatch{$idx}->{"AwayPoints"} = 0;
	$curmatch{$idx}->{"AwayCoed"} = 0;
	$curmatch{$idx}->{"HomeScore"} = "";
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
  elsif ($hs eq "" and $as =~ /\d+/) {
	$curmatch{$idx}->{"HomePoints"} = 0;
	$curmatch{$idx}->{"AwayPoints"} = 0;
	$curmatch{$idx}->{"Complete"} = 0;
	&chgcolor($notokcolor,$idx);
  }	
  elsif ($as eq "" and $hs =~ /\d+/) {
	$curmatch{$idx}->{"HomePoints"} = 0;
	$curmatch{$idx}->{"AwayPoints"} = 0;
	$curmatch{$idx}->{"Complete"} = 0;
	&chgcolor($notokcolor,$idx);
  }	
  elsif ($hs > $as) {
	#print "Home Wins.\n";
	$curmatch{$idx}->{"HomePoints"} = 6 + $curmatch{$idx}->{"HomeCoed"};
	$curmatch{$idx}->{"AwayPoints"} = 2 + $curmatch{$idx}->{"AwayCoed"};
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
  elsif ( $hs == $as ) {
	#print "Tie.\n";
	$curmatch{$idx}->{"HomePoints"} = 4 + $curmatch{$idx}->{"HomeCoed"}; 
	$curmatch{$idx}->{"AwayPoints"} = 4 + $curmatch{$idx}->{"AwayCoed"};
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
  elsif ( $hs < $as ) {
	#print "Away Wins.\n";
	$curmatch{$idx}->{"HomePoints"} = 2 + $curmatch{$idx}->{"HomeCoed"}; 
	$curmatch{$idx}->{"AwayPoints"} = 6 + $curmatch{$idx}->{"AwayCoed"};
	$curmatch{$idx}->{"Complete"} = 1;
	&chgcolor($okcolor,$idx);
  }
}


#---------------------------------------------------------------------
sub mkbuttons {
  my $top = shift;

  my $buttons = $top->Frame;
  my $butspace = $buttons->Frame->pack(-side => 'left', 
									   -fill => 'both',
									   -expand => 'yes');
  
  $butspace = $buttons->Frame->pack(-side => 'left', 
									-fill => 'both',
									-expand => 'yes');
  
  $buttons->Button(-text => 'Quit',-command => sub{exit;},
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Frame(-width => 5)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Button(-text => 'Load',-command => sub { &load_game_file($top,$game_file); },
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Button(-text => 'Save',-command => sub { 
	&save_curmatch($curweek);
	&save_game_file($top,$game_file,\%teams,\@matches,\%standings);
				   },
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Button(-text => 'Save As',-command => sub { 
	&save_curmatch($curweek);
	&save_game_file_as($top,$game_file,\%teams,\@matches,\%standings);
				   },
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Frame(-width => 5)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Button(-text => 'Update Standings',-command => sub{ &update_standings($curweek) },
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->Button(-text => 'Make Report',-command => sub{ &make_report($rpt_file) },
	)->pack(-side => 'left', -expand =>'yes');
  
  $buttons->pack(-side => 'bottom');
}


#---------------------------------------------------------------------
my $top = MainWindow->new;
$top->configure(-title => 'Soccer Scoring',
                -height => 400,
                -width => 1000,
                -background => 'white',
               );
$top->geometry('-100-100');
$top->optionAdd('*font', 'Helvetica 9');

# Menu Bar of commands
my $mbar=$top->Menu();
$top->configure(-menu => $mbar);
my $season=$mbar->cascade(-label=>"~Season", -tearoff => 0);
my $match=$mbar->cascade(-label=>"~Match", -tearoff => 0);
my $help=$mbar->cascade(-label =>"~Help", -tearoff => 0);

# Season Menu
$season->command(-label =>'~New     ', -command=> sub { 
  &init_game_file($top); },
  );
$season->command(-label =>'~Open    ', -command=> sub {
  &load_game_file($top,$game_file);
			   },
  );
$season->command(-label =>'~Save    ', -command=> sub { 
  &save_curmatch($curweek);
  &save_game_file($top,$game_file,\%teams,\@matches,\%standings);
			   },
  );
$season->command(-label =>'~Save As ', -command=> sub { 
  &save_curmatch($curweek);
  &save_game_file_as($top,$game_file,\%teams,\@matches,\%standings);
			   },
  );
$season->separator();
$season->command(-label =>'~Update Standings', -command => sub {
  &update_standings($curweek) },
  );
$season->separator();
$season->command(-label =>'~Report  ', -command => sub {
  &make_report($rpt_file) },
  );
$season->separator();
$season->command(-label =>'~Quit    ', -command=>sub{exit},
  );

# Match Menu
$match->command(-label => 'Reschedule', -command => sub {
				&match_reschedule($top,$curweek);},
  );

# Help Menu
$help->command(-label => 'Version');
$help->separator;
$help->command(-label => 'About');

# We've got two frames, one for weekly scores, another for standings,
# Now how to deal with updates to scores finishing the
# standings.... plan is to just delete the children of $standingsframe
# and re-create.  Same for week frame when it's rebuilt.

my $scoreframe=$top->Frame();
&init_scores($scoreframe,$week);
&update_scores($week);
$scoreframe->pack(-side => 'top', -fill => 'x');

my $standingsframe = $top->Frame;
&init_standings($standingsframe);
$standingsframe->pack(-side => 'top', -fill => 'x');

MainLoop;




