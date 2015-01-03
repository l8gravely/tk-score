#!/usr/bin/perl -w
#
# tk-score - Managing and reporting the results and standings of a
# soccer league that plays once a week on tuesdays.  This is reflected
# in the lack of scheduling options as currently avaible.

# Now using GIT!

use strict;

# Where you can find extra modules?
use lib "$ENV{HOME}/lib/perl";
use Season;

# Remove cwd, why?  
no lib ".";

use IO::Handle;
#use Data::Dumper;
use Getopt::Long;
use List::Util 'shuffle';
use Pod::Usage;
use YAML qw(DumpFile LoadFile);

# Non-core Perl modules we require
my $count = 0;
foreach my $mod ("Tk",	
		 "Tk::BrowseEntry", "Tk::DateEntry", "Tk::HList",
		 "Tk::ItemStyle", "Tk::DialogBox", "Tk::Month",
		 "Tk::FileSelect",
		 "Date::Calc qw(Decode_Date_US Delta_Days Date_to_Days Add_Delta_Days)",
		) {
  eval "use $mod;1";
  if ($@) {
    warn "  Missing: $mod\n";
    $count++;
  }
}
die "\nPlease install the above modules (from CPAN) to run this program.\n\n" if $count;

#---------------------------------------------------------------------
# Defaults and global variables.  
#---------------------------------------------------------------------

my $VERSION = "v1.9 (2014-11-17)";

# Version of the Game file.  
my $gf_version = "v2.0";

my $mail_from = "dsl\@stoffel.org";
my $mail_prog = "/usr/lib/sendmail";

my $default_background = "white";
my $default_background_odd = "white";
my $default_background_even = "lightgrey";

# Global font for all GUI elements
my $default_font_type = "Helvetica";
my $default_font_size = "10";
my $default_font = "$default_font_type $default_font_size";

my $game_file = "";
my $rpt_file = "new-season.rpt";
my $do_report = 0;

my $NeedSave = 0;

# Flush all output right away...
$|=1;

#---------------------------------------------------------------------
my @initial_team_names = qw(one two three four five six seven eight nine);
my @matches = ();
my @match_dates = ();
my @scores = ( '','F',0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15);
my %lining_team;
my %bye_team;
my $homeforfeit= 0;
my $homecoed = 'no';
my $homescore = " ";
my $match_datelist;

# Style Colors for DateList, made global so we can update them
# easily.  Might not need to do this down the line though....
my $dls_red;
my $dls_green;
my $dls_done;
my $dls_blue;

my $notokcolor = 'darkgrey';
my $okcolor    = 'lightgreen';

# Format is # -> Name
my @teams;

# Debugging and option parsing
my $DEBUG;
my $prog_help;
my $man;

# Used to configure DateEntry to ignore certain dates.
my @blockdates = ();

#---------------------------------------------------------------------
# These schedules should be stored in a YAML file somewhere else.
#---------------------------------------------------------------------

my $dolining = 0;   # Do teams need to line during the season?

# Week 0 is scrimmage if used.  But numbering starts from 1!!!  Data
# Structure, which should be in an YAML file instead, though this way
# it works for DSL stuff nicely.  Other leagues might have other
# needs.  
my $first_match_scrimmage = 0;

# %sched_template = ( Number_Teams => {
#                     Week => [game,...,gameN,bye,lining],
#                     ....
#                    }
#                  );    

my %sched_template = 
  # Only three matches per week here.  generate_schedule() needs to
  # handle this properly.
  ( 6 => {
	  0  => [ "3-2", "4-6", "1-5", "", "3" ],
	  1  => [ "2-1", "3-6", "4-5", "", "1" ],
	  2  => [ "3-4", "2-5", "6-1", "", "5" ],
	  3  => [ "6-4", "1-5", "2-3", "", "6" ],
	  4  => [ "4-1", "6-2", "5-3", "", "2" ],
	  5  => [ "5-6", "1-3", "4-2", "", "4" ],
	  6  => [ "5-4", "1-2", "6-3", "", "2" ],
	  7  => [ "5-2", "4-3", "1-6", "", "4" ],
	  8  => [ "5-1", "6-4", "3-2", "", "6" ],
	  9  => [ "2-6", "3-5", "1-4", "", "3" ],
	  10  => [ "3-1", "2-4", "6-5", "", "1" ],
	  11 => [ "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	  12 => [ "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	 },
    8 => {
	  0  => [ "1-7", "2-3", "5-8", "4-6", "", "1" ],
	  1  => [ "1-2", "3-4", "5-6", "7-8", "", "1" ],
	  2  => [ "5-7", "6-8", "1-3", "2-4", "", "5" ],
	  3  => [ "4-8", "1-5", "2-6", "3-7", "", "5" ],
	  4  => [ "2-5", "3-8", "4-7", "1-6", "", "3" ],
	  5  => [ "3-6", "2-7", "1-8", "4-5", "", "3" ],
	  6  => [ "1-7", "4-6", "2-8", "3-5", "", "4" ],
	  7  => [ "4-1", "7-6", "8-5", "3-2", "", "4" ],
	  8  => [ "8-7", "6-5", "4-3", "2-1", "", "6" ],
	  9  => [ "4-2", "3-1", "8-6", "7-5", "", "2" ],
	  10 => [ "7-3", "6-2", "5-1", "8-4", "", "7" ],
	  11 => [ "6-1", "7-4", "8-3", "5-2", "", "7" ],
	  12 => [ "5-4", "8-1", "7-2", "6-3", "", "8" ],
	  13 => [ "5-3", "8-2", "6-4", "7-1", "", "8" ],
	  14 => [ "2-3", "5-8", "6-7", "1-4", "", "2" ],
	  15 => [ "Make-up", "Make-up", "Make-up", "Make-up", "", "tbd" ],
	  16 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	  17 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	  18 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	 },
    9 => {
	  1  => [ "3-7", "5-9", "4-6", "2-8", "1", "9" ],
	  2  => [ "1-2", "4-9", "5-7", "6-8", "3", "9" ],
	  3  => [ "4-8", "1-3", "7-9", "5-6", "2", "8" ],
	  4  => [ "3-8", "6-7", "1-4", "2-9", "5", "8" ],
	  5  => [ "6-9", "7-8", "2-3", "1-5", "4", "6" ],
	  6  => [ "1-6", "2-4", "3-9", "5-8", "7", "6" ],
	  7  => [ "2-5", "1-7", "8-9", "3-4", "6", "5" ],
	  8  => [ "4-7", "3-5", "1-8", "2-6", "9", "5" ],
	  9  => [ "4-5", "3-6", "2-7", "1-9", "8", "4" ],
	  10 => [ "2-8", "4-6", "5-9", "3-7", "1", "4" ],
	  11 => [ "6-8", "5-7", "4-9", "1-2", "3", "7" ],
	  12 => [ "5-6", "7-9", "1-3", "4-8", "2", "7" ],
	  13 => [ "2-9", "1-4", "6-7", "3-8", "5", "1" ],
	  14 => [ "1-5", "2-3", "7-8", "6-9", "4", "1" ],
	  15 => [ "5-8", "3-9", "2-4", "1-6", "7", "3" ],
	  16 => [ "3-4", "8-9", "1-7", "2-5", "6", "3" ],
	  17 => [ "2-6", "1-8", "3-5", "4-7", "9", "2" ],
	  18 => [ "1-9", "2-7", "3-6", "4-5", "8", "2" ],
	  19 => [ "Make-up", "Make-up", "Make-up", "Make-up", "", "tbd" ],
	  20 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	  21 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	  22 => [ "Playoffs", "Playoffs", "Playoffs", "Playoffs", "", "tbd" ],
	 },
  );

my $playoff_sched = 
  { "Three Weeks, 8 Teams" => 
    { 1 => [ "1-8 (A)", "2-7 (B)", "3-6 (C)", "4-5 (D)" ], 
      2 => [ "W:A-W:D (E)", "W:B-W:C (F)", "L:D-L:A (G)", "L:C-L:B (H)" ],
      3 => [ "W:E-W:F (Final)", "L:E-L:F", "W:G-W:H", "L:G-L:H" ],
    },
    "Two Weeks, 8 Teams" => 
    { 1 => [ "1-4 (A)", "2-3 (B)", "5-8 (C)", "6-7 (D)" ], 
      2 => [ "W:A-W:B (Final)", "L:A-L:B", "W:C-W:D", "L:C-L:D" ],
    },
		    };

# Number of teams supported by schedules.  This should really be
# broken out into their own module.  Also, the 6 team schedule assumes
# three fields per/week, 8 and 9 team schedules assume 4 fields
# per/week.  Need to update logic somehow to present this properly. 
my @teamcnt = sort(qw(6 8 9));
my $max_numteams = $teamcnt[$#teamcnt];
my $numteams = $teamcnt[0];

my @playoff_rnds = qw(3 2 1 0);
my @games_per_week = qw(1 2 3 4 5 6);

# FIXME!  This needs to be much more dynamic in how we figure it out...
my $matches_per_week = 4;

#my $num_playoffs = $playoff_rnds[0];

# Two rounds of games for each team playing every other team.
my $numweeks = ($numteams - 1) * 2;
my $week = 1;
my $curweek = 0;
my $curdate = "";
my $weekdate= "";
my @weeks;

# Per-team standings.  Re-calculated depending on the week showing.
my $cnt = 1;
my %curmatch;
my %standings;
my %season;

#---------------------------------------------------------------------
# Sort the %standings array (see zero_standings for format) by RANK,
# W, L, T and maybe more...

#---------------------------------------------------------------------
sub cleanup_and_exit {
  my $top = shift;
  my $game_file = shift;

  if ($NeedSave) {
    print "We gotta save first dude!\n\n";
    
    my $text = "You have unsaved changes, do you want to Save and Exit, Exit without Save, or return to editing the	Season?";
    
    my $dialog = $top->DialogBox(-title => "Unsaved changes!",
				 -buttons => [ 'Save and Exit', 
					       'Exit without Save',
					       'Cancel', ],
				 -default_button => 'Cancel');
    $dialog->add('Label', -text => $text, -width => '30');
    
    my $ok = 1;
    while ($ok) {
      my $answer = $dialog->Show( );
      
      return if ($answer eq "Cancel");
      &do_exit($dialog,$top) if ($answer eq "Exit without Save");
      
      if ($answer eq "Save and Exit") {
	$game_file = &save_season_file_as($top, $game_file,
					\@teams,\@matches,\%standings,\%season);
	# Only exit if we actually picked a filename to save to...
	if ($game_file ne "") {
	  &do_exit($dialog,$top);
	}
      }
    }
  }
  else {
    &do_exit($top);
  }
}


#---------------------------------------------------------------------
sub do_exit {
  
  foreach my $top (@_) {
    $top->destroy;
  }
  &Tk::exit;
}

#---------------------------------------------------------------------
# Crying out to be object oriented.  Used by display widgets to enter
# weekly results.  
sub init_matches_per_week {
  
  # Matches per-week that are played.
  my $num = shift @_;
  
  my %t;
  
  for (my $m=1; $m <= $num; $m++) {
    $t{$m}->{HomeScore} = "";
    $t{$m}->{HomeCoed} = 0;
    $t{$m}->{HomePoints} = "";
    $t{$m}->{AwayScore} = "";
    $t{$m}->{AwayCoed} = 0;
    $t{$m}->{AwayPoints} = "";
    $t{$m}->{PointsLabels} = ();
    $t{$m}->{Type} = "G";
  }
  return %t;
}

#---------------------------------------------------------------------
# Decodes a date and returns the number of days from Jan 1, 1970.
sub my_dtd {
  my $d = shift @_;
  return 0 if ($d eq "");
  #print "   my_dtd($d)\n";
  my @a = Decode_Date_US($d);
  return(Date_to_Days($a[0],$a[1],$a[2]));
}
  
#---------------------------------------------------------------------
# sort matches by week then time then field

sub byweektimefield {
  $a->{Week} <=> $b->{Week} ||
    $a->{Time} cmp $b->{Time} ||
      $a->{Field} cmp $b->{Field};
}

#---------------------------------------------------------------------
# sort matches by date then time then field

sub bydatetimefield {
  
  $a <=> $b ||
    $a->{DTD} <=> $b->{DTD} ||
      $a->{Time} cmp $b->{Time} ||
	$a->{Field} cmp $b->{Field};
}

#---------------------------------------------------------------------
# If $new is blank, update all dates...  I think.
sub updateweekdates {
  my $week = shift;
  my $old = shift;
  my $new = shift;
  
  print "updateweekdates($week, \"$old\",\"$new\")\n";
  
  # check for bogus inputs
  if ($new eq "" and $old eq "") {
    return 0;
  }
  my %dates;
  my $found=0;
  foreach my $match (sort bydatetimefield @matches) {
    if ($match->{"Date"} eq $old && $match->{"Week"} == $week) {
      $match->{"Date"} = "$new";
      # Make sure we update the optimzed sort
      $match->{"DTD"} = &my_dtd($match->{'Date'});
      $match->{"DateOrig"} = "$old";
      print "  match->{Date} = ", $match->{Date}, "\n";
      $found++;
    }
  }
  return $found;
}

#---------------------------------------------------------------------
# Input:  Week Number
# Return: Date of the matches that week.
# Notes:  All matches are on the same day.

sub week2date {
  my $w = shift;
  
  foreach my $match (sort bydatetimefield @matches) {
    if ($match->{"Week"} == $w) {
      my $d = $match->{Date};
      #print "Week = $w, Date = $d\n";
      return $d;
    }
  }
}

#---------------------------------------------------------------------
# Input:  Date
# Return: Week number
# Notes:  All matches are on the same date.

sub date2week {
  my $d = shift;
  
  foreach my $match (sort bydatetimefield @matches) {
    if ($match->{"Date"} eq $d) {
      my $w = $match->{Week};
      #print "Week = $w, Date = $d\n";
      return $w;
    }
  }
  # Error condition...
  return 0;
}

#---------------------------------------------------------------------
# Checks a global array of dates which are not allowed to be used.
# Might need to be changed into a callback which pulls out the dates
# to dis-allow instead, but that's easy to do...

sub dateentry_cfg {
  my(%args) = @_;
  
  if ($args{-date}) {
    my($day,$month,$year) = @{ $args{-date} };
    my $dw = $args{-datewidget};
    my $grep = scalar(grep(m/$month\/$day\/$year/, @blockdates));
    if ($grep != 0) {
      if (defined $dw) {
	$dw->configure(-state => 'disabled');
      }
    }
  }
}

#---------------------------------------------------------------------
# Change the date of a match

sub match_reschedule {
  my $top = shift;
  my $old_date = shift;
  
  my $week = &date2week($old_date);
  
  print "match_reschedule($old_date)\n";
  
  # Update the blockdates before we reschedule.
  foreach my $i (&get_match_dates) { 
    push @blockdates, $i->[1];
  }
  
  my $new_date = "";
  
  my $dialog = $top->DialogBox(-title => "Reschedule Match Date",
                               -buttons => [ 'Ok', 'Cancel' ],
                               -default_button => 'Ok');
  $dialog->add('Label', -text => "Old Date: $old_date")->pack(-side => 'top');
  $dialog->add('Label', -text => "New Date (MM/DD/YYYY)")->pack(-side => 'left');
  $dialog->add('DateEntry', -textvariable => \$new_date, 
	       -width => 12,
	       -configcmd => \&dateentry_cfg)->pack(-side => 'left');
  
  my $ok = 1;
  while ($ok) {
    my $answer = $dialog->Show( );
    
    if ($answer eq "Ok") {
      print "New Date = $new_date\n";
      if ($new_date =~ m/^\d\d\/\d\d\/\d\d\d\d$/) {
        $ok--;
	
	# Gotta be careful here... don't allow matches on an existing
	# date!  Or at least also use week number to keep them sane...
	# BUT!  We can allow them on Makeup days or Makeup/Playoff days.
	
        my $num_matches = &updateweekdates($week,$old_date,$new_date);
	&update_datelist($match_datelist);
	
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
      $ok--;
    }
  }
}

#---------------------------------------------------------------------
sub error_msg {

  my $msg = shift;

  print "MSG: $msg\n";
  
}

#---------------------------------------------------------------------
# Validates the data entered when building a new season.

sub validate {
  my $num = shift @_;
  my $start = shift @_;
  my $descrip = shift @_;
  my $tref = shift @_;
  my @t_entry = @$tref;

  if ($start eq "") {
    error_msg("Need a start date.");
    return 0;
  }
  elsif ($descrip eq "") {
    error_msg("Need a Season Description.");
    return 0;
  }
  else {
    my $cnt=0;
    foreach my $i (@t_entry) {
      $cnt++ if ($i->get ne "");
    }
    if ($cnt < $num) {
      error_msg("You entered $cnt team names, you need at least $num.");
      return 0;
    }
  }
  return 1;
}

#---------------------------------------------------------------------
# Make sure all dates are mm/dd/yyyy, but we're not too hot on error
# checking here...
sub fix_week_date_fmt {
  my $orig = shift;
  my $new = $orig;
  my ($y,$m,$d);

  # Returns Y,M,D or empty list if error.
  if (($y,$m,$d) = Decode_Date_US($orig)) {
    $new = sprintf("%02s/%02s/%4s",$m,$d,$y);
  }
  return $new;
}

#---------------------------------------------------------------------
# Takes a date string and returns the date seven days on in MM/DD/YYYY
sub inc_by_week {
  my $cur = shift;
  my ($y,$m,$d) = Decode_Date_US($cur);
  #print " inc_by_week($y/$m/$d) + 7d = ";
  ($y,$m,$d) = Add_Delta_Days($y,$m,$d,7);
  #print "  ($y/$m/$d)\n";
  $cur = sprintf("%02s/%02s/%4s",$m,$d,$y);
  return $cur;
}

#---------------------------------------------------------------------
sub check_holidays {
  my $cur = shift;
  my @hols = @_;

  my $ishol = 0;
  my ($cy,$cm,$cd) = Decode_Date_US($cur);
  foreach my $h (@hols) {
    my ($hy,$hm,$hd) = Decode_Date_US($h);
    if (Delta_Days($cy,$cm,$cd,$hy,$hm,$hd) == 0) {
      $ishol = 1;
    }
  }

  #print "check_holidays($cur) = $ishol\n";
  return $ishol;
}

#---------------------------------------------------------------------
# takes in a number of teams and a hash of team names and randomizes
# them.  This looks involved, but it's because I pass in a hash of
# entry values, which I want to randomize...

sub randomize_teams {
  my $ref = shift;

  my @entry = @$ref;
  my @h;
  
  print "randomize_teams( ... )\n" if $DEBUG;
  
  foreach my $e (@entry) {
    my $g = $e->get;
    push @h, $g unless $g eq "";
    $e->delete(0,length($g));
  }

  for (my $i = 5; $i>0; $i--) {
    @h = shuffle @h;
  }

  foreach my $e (@entry) {
    $e->insert(0,shift @h || "");
  }
}

#---------------------------------------------------------------------
# Takes input from the "Setup a new Season" window and generates a
# schedule which you need to approve.  FIXME: add summary and approval window.
#
# TODO: pass in a single structure will all info, return proper
# schedule somehow.  Second hashref?

sub generate_schedule {
  my $tmp_ref;

  my $win = shift @_;
  $tmp_ref = shift @_;
  my $num_teams = $$tmp_ref;

  $tmp_ref = shift @_;
  my @team_names = @$tmp_ref;

  $tmp_ref = shift @_;
  my $season_name = $$tmp_ref;

  $tmp_ref = shift @_;
  my $start_date = $$tmp_ref;

  $tmp_ref = shift @_;
  my $time_field_lb = $$tmp_ref;

  $tmp_ref = shift @_;
  my $num_playoffs = $$tmp_ref;

  $tmp_ref = shift @_;
  my $do_scrimmage = $$tmp_ref;

  $tmp_ref = shift @_;
  my $do_lining = $$tmp_ref;

  $tmp_ref = shift @_;
  my $sched_makeup = $$tmp_ref;

  $tmp_ref = shift @_;
  my $hlb = $$tmp_ref;

  $tmp_ref = shift @_;
  my $done_but = $$tmp_ref;

  my @times_fields;
  
  # Validate inputs.  Should be in the Setup a New Season window, with
  # the 'Done' button disabled until all the required info is entered.

  print "generate_schedule()\n";
  print "  Num Teams:  $num_teams\n";
  print "  Start Date: $start_date\n";
  print "  Scrimmage = $do_scrimmage\n";
  print "  Schedule Makeup Week = $sched_makeup\n";
  print "  Playoff rounds = $num_playoffs\n";
  print "  Season Name = $season_name\n";

  if (&validate($num_teams,$start_date,$season_name,\@team_names)) {
    
    my $num_games_week = $#times_fields+1;
    print "  Num_games_week = $num_games_week\n";
    my $win = MainWindow->new();
    $win->title("Proposed Schedule");
    $win->configure(-height => 400,
		    -width => 400,
		    -background => $default_background,
		   );
    $win->optionAdd('*font*' => $default_font);
    
    # Top Frame: Proposed Schedule
    my $sched_fr = $win->Frame(-pady => 10, -border => 1);
    
    # Buttons go here...
    my $but_fr = $win->Frame(-pady => 10, -border => 1);
    
    # Build the Schedule HList, scolled if need be.
    $sched_fr->Label(-text => 'Proposed Schedule: ', 
		     -width => 30)->pack(-side => 'top');
    my $sl = $sched_fr->Scrolled('HList', -scrollbars => 'ow', -columns => 8, 
				 -header => 1, -selectmode => 'single', -width
				 => 80,)->pack(-fill => 'x');
    
    $sl->header('create', 0, -itemtype => 'text', -text => 'Week');
    $sl->columnWidth(0, -char => 6);
    $sl->header('create', 1, -itemtype => 'text', -text => 'Date');
    $sl->columnWidth(1, -char => 10);
    
    my $base = 2;
    for (my $i = 0; $i <= $#times_fields; $i++) {
      $sl->header('create', $base+$i, -itemtype => 'text', -text => $times_fields[$i]->{Time}." ". $times_fields[$i]->{Field});
      $sl->columnWidth($base+$i, -char => 10);
    }
    
    $base = $base + $#times_fields + 1;
    # Only for outdoor schedules..
    $sl->header('create', $base, -itemtype => 'text', -text => 'Lining');
    $sl->columnWidth(7, -char => 6);
    
    
    # Create the buttons
    my $accept_but = $but_fr->Button(-text => 'Accept', -command => [ $win => 'destroy' ]);
    my $cancel_but = $but_fr->Button(-text => 'Cancel', -command => [ $win => 'destroy' ]);
    
    # Spacer frames
    $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
    $accept_but->pack(-side => 'left', -fill => 'x');
    $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
    $cancel_but->pack(-side => 'left', -fill => 'x');
    $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
    
    
    $sched_fr->pack(-side => 'top', -fill => 'x');
    $but_fr->pack(-side => 'bottom', -fill => 'x');
    
    my $n=1;
    foreach my $e (@team_names) {
      my $g = $e->get;
      if ($g ne "" && $n <= $num_teams) {
	print "  $n -> $g\n";
	$teams[$n++] = $g;
      }
    }
    
    # Get holidays, if any, to be skipped.
    my $hlb_cnt = $hlb->size;
    my @hols = $hlb->get(0,$hlb_cnt);
    print "Holidays:\n";
    foreach my $h (sort @hols) {
      print "  $h\n";
    }
    print "\n";
    
    my $cur_date = $start_date;
    
    # Check for a holiday on the start_date, not likely, but more
    # durable...  Do this in a loop, since we can have holidays
    # spanning multiple weeks.
    while (&check_holidays($cur_date, @hols)) {
      $cur_date = &inc_by_week($cur_date);
    }
    # Store Season Setup options
    $season{Lining} = $do_lining;
    $season{Description} = $season_name;
    $season{Scrimmage} = $do_scrimmage;
    $season{Playoff_Rounds} = $num_playoffs;
    $season{Number_Teams} = $num_teams;
    $season{Matches_per_Week} = 3;

    # Initialize Matches array:
    print "Num teams = $num_teams\n";
    my %template = %{$sched_template{$num_teams}};
    
    # Actual week in schedule, template starts at zero for scrimmage
    # week, which is not scored, but _is_ scheduled.  
    my $sched_week = 1;
    $sched_week = 0 if $do_scrimmage;
    
    my $matchid = 0;
    my $is_lining; 
    my $cnt_playoffs = 0;

    # Sort by week number.  
    foreach my $tmpl_wk (sort { $a <=> $b } keys %template) {
      
      # Skip scrimmage week(s) 
      next if ($tmpl_wk == 0 && $do_scrimmage == 0);
      
      my @week_sched = @{$template{$tmpl_wk}};
      
      # Skip Makeup Week
      next if ($sched_makeup != 1 && $week_sched[0] eq "Make-up");
      
      # Count how many playoffs we scheduled vs Playoff Round.
      next if ($week_sched[0] eq "Playoffs" && $cnt_playoffs++ == $num_playoffs);
      
      # Note!  Week Schedule assumes two fields and two games on each
      # field, along with a Bye and Lining column. 

      # Since we have N matches + 2 columns, pop off the last two,
      # which are for byes[5] and lining[6].  This is ugly and I
      # should just change the data structure.  FIXME!

      my $team_to_line = pop @week_sched;
      my $team_with_bye = pop @week_sched;
      $lining_team{$week} = "";

      if ($do_lining) {
	$dolining = 1;

	# Numbers are team lining, otherwise skip
	if ($team_to_line =~ m/^\d+$/) {
	  $lining_team{$week} = $team_to_line;
	} else {
	  $lining_team{$week} = "tbd";
	}
      }
      
      # If we have an odd number of teams, there will be a bye once a
      # week for some team, otherwise empty.

      $bye_team{$week} = $team_with_bye;
      
      # Now fill in the schedule for games this week.
      my $i = 0;
      my $game;
      print "  Date: $cur_date : Week: $sched_week : ";
      foreach my $match (@week_sched) {
	# copy our pre-setup match template and fill in the proper fields...
	my $game = { };
	my ($home, $away);
	# Matches are #-#, if we don't see a -, it's something else
	print " $match\t";
	if ($match =~ m/^\d+\-\d+$/) {
	  ($home, $away) = split("-",$match);
	  # Game Type depends on sched_week and then makeup/playoffs counts.
	  $game->{Type} = "G";
	  $game->{Type} = "S" if ($sched_week == 0);
	}
	elsif ($match eq "Make-up" && $sched_makeup) {
	  $game->{Type} = "M";
	  $home = "tbd";
	  $away = "tbd";
	}
	elsif ($match eq "Playoffs") {
	  $game->{Type} = "P";
	  $home = "tbd";
	  $away = "tbd";
	}

	$game->{Date} = $cur_date;
	$game->{DTD} = &my_dtd($cur_date);
	$game->{DateOrig} = "";
	$game->{Week} = $sched_week;
	$game->{Home} = $home;
	$game->{HomeScore} = "";
	$game->{HomeCoed} = 0;
	$game->{HomePoints} = 0;
	$game->{Away} = $away;
	$game->{AwayScore} = "";
	$game->{AwayCoed} = 0;
	$game->{AwayPoints} = 0;
	$game->{Complete} = 0;
	$game->{MatchID} = $matchid++;
	
	# Template now pulls start time and location from an array
	# matching the number of matches per_day.  Now explicitly
	# picked by end user.
	
	$game->{Field} = $times_fields[$i]->{Field};
	$game->{Time} = $times_fields[$i]->{Time};
	$i++; 
	push @matches, $game;
      }

      print "\n";
      
      # Increment date by one week
      $cur_date = &inc_by_week($cur_date);
      while (&check_holidays($cur_date,@hols)) {
	$cur_date = &inc_by_week($cur_date);
      }
      $sched_week++;
    }

    # Need to put in a message box here which enables the 'Done'
    # button if it's all ok.  
    $done_but->configure(-state => 'normal');
  }
}

#---------------------------------------------------------------------
# This is where you hit the Done button once the generate_schedule()
# has finished it's work.

sub accept_schedule {

  my $top = shift;
  my $win = shift;
  my $desc = shift;

  print "accept_schedule($desc)\n";
  $top->configure(title => $desc);
  $win->destroy;
  &update_datelist($match_datelist);
  &load_curmatch($match_dates[0]);
  &update_standings($match_dates[0]);
}

#---------------------------------------------------------------------
# add_holiday
sub add_holiday {

  my $win = shift;
  my $holsref = shift;
  my $holref = shift;
  my $hlb = shift;
  
  print "add_holiday()\n";
  
  my %hols = %$holsref;
  print "  Holiday: $holref\n";
}

#---------------------------------------------------------------------
# del_holiday
sub del_holiday {

  my $win = shift;
  my $holsref = shift;
  my $holref = shift;
  my $hlb = shift;

  print "del_holiday()\n";


}

#---------------------------------------------------------------------
sub teams_rename {

  my $top = shift;
  my $ref = shift;
  my @ts = @$ref;

  print "teams_rename()\n";

  my $win = MainWindow->new();
  $win->title("Rename Team");
  $win->configure(-height => 400,
		  -width => 400,
		  -background => $default_background,
		  );
  $win->optionAdd('*font*', $default_font);

  my $setup_fr = $win->Frame(-borderwidth => 1, -relief => 'solid');

  for(my $i = 0; $i <= $#ts; $i++) {
    next if (!defined $ts[$i]);
    $setup_fr->Entry(-textvariable => \$ts[$i], -width => '20')->
      pack(-side => 'top');
  }
  $setup_fr->pack(-side => 'top', -fill => 'x');

  my $but_fr = $win->Frame(-borderwidth => 1, -relief => 'solid');
  my $done_but = $but_fr->Button(-text => "Done", -command => [ $win => 'destroy' ]);
  my $cancel_but = $but_fr->Button(-text => "Cancel", -command => [ $win => 'destroy' ]);

  # Spacer frames
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
  $done_but->pack(-side => 'left', -fill => 'x');
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
  $cancel_but->pack(-side => 'left', -fill => 'x');
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);

  $but_fr->pack(-side => 'top', -fill => 'x');
}


#---------------------------------------------------------------------
sub init_new_season {
  my $top = shift;
  
  my $tmf;  # Temp Frame

  print "init_new_season()\n";

  my $game_per_week = 4;
  my $playoff_cnt = $playoff_rnds[0];
  my $first_match_scrimmage = 0;
  my $teams_line_fields = 0;
  my $schedule_makeup = 1;
  my $start_date = "";
  my $descrip = "";

  # Reset to nothing, since it's a new season.
  $game_file = "";

  my $win = MainWindow->new();
  $win->title("Setup a new Season");
  $win->configure(-height => 400,
                  -width => 800,
                  -background => $default_background,
		 );
  $win->geometry('-500-500');
  $win->optionAdd('*font', $default_font);
  
  my $t;
  
  my $top_fr = $win->Frame();
  $top_fr->pack(-fill => 'both');

  my $setup_fr = $top_fr->Frame(-borderwidth => 1, -relief => 'solid');
  my $team_fr = $top_fr->Frame(-borderwidth => 1, -relief => 'solid');
  my $sched_fr = $top_fr->Frame(-borderwidth => 1, -relief => 'solid');
  
  $setup_fr->pack(-side => 'left', -fill => 'y');
  $team_fr->pack(-side => 'left', -fill => 'y');
  $sched_fr->pack(-side => 'right', -fill => 'y');
  
  my $opt_fr = $setup_fr->Frame(-borderwidth => 0, -width => 40, -relief => 'solid');
  my $opt_left_fr = $opt_fr->Frame(-borderwidth => 0, -relief => 'solid');
  my $opt_middle_fr = $opt_fr->Frame(-borderwidth => 0, -width => 60, -relief => 'solid');
  my $opt_right_fr = $opt_fr->Frame(-borderwidth => 0, -relief => 'solid');
  
  $t = $setup_fr->Frame(-borderwidth => 1, -relief => 'solid');
  $t->Label(-text => 'Season Description:')->pack(-side => 'left');
  $t->Entry(-textvariable => \$descrip, -width => 40)->pack(-side => 'left', -fill => 'x');
  $t->pack(-side => 'top', -fill => 'x');
  
  $opt_fr->pack(-side => 'top', -fill => 'x');
  $opt_left_fr->BrowseEntry(-label => 'Num Teams',
			    -variable => \$numteams,
			    -width => 3,
			    -choices => \@teamcnt,
			   )->pack(-side => 'top', -fill => 'x');
  
  $opt_right_fr->BrowseEntry(-label => 'Playoff Rounds',
			     -variable => \$playoff_cnt,
			     -width => 3,
			     -choices => \@playoff_rnds,
			    )->pack(-side => 'top', -fill => 'x');
  
  $opt_left_fr->BrowseEntry(-label => 'Games per Week',
			    -variable => \$game_per_week,
			    -width => 3,
			    -choices => \@games_per_week,
			   )->pack(-side => 'top', -fill => 'x');
  
  $opt_right_fr->Checkbutton(-variable => \$first_match_scrimmage,
			     -text => "First Match for Scrimmage? ",
			    )->pack(-side => 'top', -fill => 'x');
  
  $opt_left_fr->Checkbutton(-variable => \$teams_line_fields,
			    -text => "Teams Line Fields?",
			   )->pack(-side => 'top', -fill => 'x');
  
  $opt_right_fr->Checkbutton(-variable => \$schedule_makeup,
			     -text => "Schedule a makeup Week?",
			    )->pack(-side => 'top', -fill => 'x');
  
  $opt_left_fr->pack(-side => 'left', -fill => 'x');
  $opt_middle_fr->pack(-side => 'left', -fill => 'x');
  $opt_right_fr->pack(-side => 'left', -fill => 'x');
  
  $t = $setup_fr->Frame(-borderwidth => 1, -relief => 'solid');
  $t->Label(-text => 'Start Date:')->pack(-side => 'left');
  $t->DateEntry(-textvariable => \$start_date)->pack(-side => 'left');
  $t->pack(-side => 'top', -fill => 'x');
  
  my %time_fields;
  my @times_fields;
  my $time;
  my $field;
  
  #---------------------
  $tmf = $setup_fr->Frame(-borderwidth => 1, -relief => 'solid');

  $tmf->Label(-text => 'Time:')->pack(-side => 'left');
  $tmf->Entry(-textvariable => \$time)->pack(-side => 'left');
  
  $tmf->Label(-text => 'Field:')->pack(-side => 'left');
  $tmf->Entry(-textvariable => \$field)->pack(-side => 'left');
  
  # Create the listbox first, even though the add button gets packed
  # above it within the temp_middle_frame (tmf).  
  
  my $time_field_lb = $setup_fr->Scrolled('HList', -scrollbars => "e", -columns => 2, -header => 1,
					  -height => 3, -selectmode => "single",
					  -width => 30, -heigh => 5)->pack(-fill => 'x');
  $dls_blue = $time_field_lb->ItemStyle('text', -foreground => '#000080', -background => $default_background, -anchor=>'w'); 
  $time_field_lb->header('create', 0, -itemtype => 'text', -text => 'Time');
  $time_field_lb->columnWidth(0,-char => 15);
  $time_field_lb->header('create', 1, -itemtype => 'text', -text => 'Field');
  $time_field_lb->columnWidth(1,-char => 15);
  
  my $dfadd_b = $tmf->Button(-text => 'Add',-command => sub {
			       if ($time ne '' && $field ne '') {
				 # Creates new child at end
				 my $e = $time_field_lb->addchild("");
				 $time_field_lb->itemCreate($e,0,-itemtype => 'text', -text => $time, -style => $dls_blue);
				 $time_field_lb->itemCreate($e,1,-itemtype => 'text', -text => $field, -style => $dls_blue);
				 $time = '';
				 $field = '';

			    } }
			 )->pack(-side => 'left');
  
  my $dfdel_b = $tmf->Button(-text => 'Delete Time/Field',-command => sub
			     { $time_field_lb->delete('entry',$time_field_lb->info('selection')) 
				 if $time_field_lb->info('selection');
			       $time = ''; 
			       $field = '';
			     }
			    );
  
  
  $dfadd_b->pack(-side => 'left', -fill => 'x');
  $dfdel_b->pack(-side => 'bottom', -fill => 'x');
  $tmf->pack(-side => 'top', -fill => 'x');
  

  #---------------------
  # Holidays Frame and buttons
  my %hols;
  my $holiday;

  $tmf = $setup_fr->Frame(-borderwidth => 1, -relief => 'solid');
  $tmf->Label(-text => 'Holiday(s):')->pack(-side => 'left');
  $tmf->DateEntry(-textvariable => \$holiday)->pack(-side => 'left');
  
  # Create the listbox first, even though the add button gets packed
  # above it within the temp_middle_frame (tmf).  
  
  my $holiday_lb = $setup_fr->Scrolled("Listbox", -scrollbars => "e",
				   -height => 3, -selectmode => "single");
  
  my $hfadd_b = $tmf->Button(-text => 'Add',-command => sub {
			       if ($holiday ne '') {
				 $holiday_lb->insert('end',$holiday);
				 $holiday = '';
			       } }
			    );
  $hfadd_b->pack(-side => 'left', -fill => 'x');
  
  my $hfdel_b = $setup_fr->Button(-text => 'Delete Holiday',-command => sub
				  { $holiday_lb->delete($holiday_lb->curselection) if $holiday_lb->curselection;
				    $holiday = ''; }
			   );
  
  $tmf->pack(-side => 'top', -fill => 'x');
  $holiday_lb->pack(-side => 'top', -fill => 'x');
  $hfdel_b->pack(-side => 'bottom', -fill => 'x');
  
  #---------------------
  # Right Frame: Teams
  my @teams_temp;
  my @entries;
  $team_fr->Label(-text => 'Team Names:')->pack(-side => 'top');
  for (my $i=1; $i <= $max_numteams; $i++) {
    my $f = $team_fr->Frame();
    $f->Label(-text => " $i ", -width => 6)->pack(-side => 'left');
    push @entries, $f->Entry(-textvariable => \$teams_temp[$i], 
			     -width => 25,
			    )->pack(-side => 'left');
    $f->pack(-side => 'top', -fill => 'x');

    # Fill in temp names
    $teams_temp[$i] = $initial_team_names[$i];
  }
  
  # Let's me be lazy and enter team names, then randomize them.
  my $rand_but = $team_fr->Button(-text => 'Randomize Teams', 
				  -command => [ \&randomize_teams, \@entries ],
				 );
  $rand_but->pack(-side => 'bottom', -fill => 'x');

  # Buttons at bottom of frame, one for Quit, one to Generate, one to
  # Accept proposed season.  Idea is that you can "Generate a schedule
  # multiple times, but only accept it once.  FIXME: Done needs work.
  
  my $but_fr = $win->Frame(-borderwidth => 1, -relief => 'solid');
  
  my $cancel_but = $but_fr->Button(-text => "Cancel", -command => [ $win => 'destroy' ]);
  my $done_but = $but_fr->Button(-text => "Done", -state => 'disabled',
				 -command => [ \&accept_schedule, $top, $win, $descrip ]
				);
  
  my $gen_but = $but_fr->Button(-text => "Generate Schedule", 
				-command =>  [
					      \&generate_schedule, $win, \$numteams,
					      \@entries, \$descrip, \$start_date,
					      \$time_field_lb, \$playoff_cnt, \$first_match_scrimmage,
					      \$teams_line_fields, \$schedule_makeup, \$holiday_lb, 
					      \$done_but ] 
			       );
  
  # add in spacers...
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
  $cancel_but->pack(-side => 'left', -fill => 'x');
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
  $gen_but->pack(-side => 'left', -fill => 'x');
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'left', -expand => 1);
  $done_but->pack(-side => 'right', -fill => 'x');
  $but_fr->Frame(-borderwidth => 0, -relief => 'flat')->pack(-side => 'right', -expand => 1);
  
  # Pack entire frame  of buttons...
  $but_fr->pack(-side => 'bottom', -fill => 'x');
}

#---------------------------------------------------------------------
# Takes current date, returns date of NEXT match, or "" if none.

sub get_next_match_date {

  my $cur_date = shift @_;
  print "get_next_match_date($cur_date) = ";
  
  my $found = 0;
  foreach my $m (sort bydatetimefield @matches) {
    # We will find four matches before we fall through...
    if ($cur_date eq "$m->{Date}") {
      $found++;
    }
    # We found a match, so this should be the first new date.
    elsif ($found > 0) {
      print "$m->{Date}\n";
      return $m->{Date};
    }
  }
  print "<empty>\n";
  return "";
}

#---------------------------------------------------------------------
# Accessor for date info stored in each match.  Returns an array of
# arrays with date(s) for all matches, sorted by date.  Stupid format.
# FIXME

sub get_match_dates {

  my %wks;
  my $w;
  my @t;

  print " get_match_dates()\n";
  
  foreach my $m (@matches) {
    $w = $m->{'Week'};
    
    # FIXME: piss-poor inefficient....
    $wks{$w}{COMP} = &all_matches_complete($w);
    
    $wks{$w}{T} = $m->{'Type'};
    $wks{$w}{D} = $m->{'Date'};
    # Optimize out Date::Calc Date_to_Days calls a bit.
    $wks{$w}{DTD} = &my_dtd($m->{'Date'});
    if (defined $m->{"DateOrig"}) {
      $wks{$w}{O} = $m->{'DateOrig'};
    } else {
      $wks{$w}{O} = "               ";
    }      
  }

  # Returning an array of crap... should just be dates, used to index
  # into the @matches array.  

  foreach my $k (sort { $wks{$a}->{DTD} <=> $wks{$b}->{DTD} } keys %wks) {
    push @t, [ $k, $wks{$k}{D}, $wks{$k}{O}, $wks{$k}{T},$wks{$k}{COMP} ];
  }

  return @t;
}

#---------------------------------------------------------------------
sub datelist_browse {
  my $hl = shift;
  my ($path) = (@_);

  my $week = $hl->itemCget($path,0,-text);
  my $date = $hl->itemCget($path,1,-text);
  my $old =  $hl->itemCget($path,2,-text);

  #print "hl_browse($path) (week = $week, date = $date)\n";

  &update_scores($date);

  # Hack to try and update the matchlist when a set of matches is
  # completed, or updated to NOT be complete any more.
  #&update_datelist($match_datelist);
  
}

#---------------------------------------------------------------------
sub update_datelist {
  my $hl = shift;

  print "update_datelist()\n";
  
  # Colors.  Wish I could change colors of box borders...
  $dls_red = $hl->ItemStyle('text', -foreground => '#800000', -background => $default_background); 
  $dls_blue = $hl->ItemStyle('text', -foreground => '#000080', -background => $default_background, -anchor=>'w'); 
  $dls_green = $hl->ItemStyle('text', -foreground => 'green', -background => $default_background, -anchor=>'w'); 
  $dls_done = $hl->ItemStyle('text', -background => 'lightgreen');
  
  $hl->delete('all');
  foreach my $key (&get_match_dates) {
    #print "  get_match_dates: ". join(", ",@$key) . "\n";
    my $e = $hl->addchild("");
    $hl->itemCreate($e, 0, -itemtype=>'text', -text => $key->[0], -style=>$dls_red); 
    $hl->itemCreate($e, 1, -itemtype=>'text', -text => $key->[1], -style=>$dls_blue); 
    $hl->itemCreate($e, 2, -itemtype=>'text', -text => $key->[2], -style=>$dls_blue); 
    $hl->itemCreate($e, 3, -itemtype=>'text', -text => $key->[3], -style=>$dls_blue); 

    # If the scoring is complete, color it done.
    if ($key->[4]) {
      $hl->itemConfigure($e, 0, -style => $dls_done);
      $hl->itemConfigure($e, 1, -style => $dls_done);
      $hl->itemConfigure($e, 2, -style => $dls_done);
      $hl->itemConfigure($e, 3, -style => $dls_done);
    }
  }
}

#---------------------------------------------------------------------
sub init_datelist {
  my $top = shift;
  print "init_datelist()\n";
  
  my @widths = ( 6, 16, 16, 6);
  my $tw = 0;
  foreach (@widths) {$tw += $_;}
  
  my $hl = $top->Scrolled('HList', -scrollbars => 'ow',
                          -columns=> $#widths+1, -header => 1, 
			  -height => 15,
			  -selectmode => 'single', -width => $tw,
                         )->pack(-fill => 'y'); 
  $hl->configure(-browsecmd => [ \&datelist_browse, $hl ]);
  $hl->header('create', 0, -itemtype => 'text', -text => "Week");
  $hl->columnWidth(0, -char => $widths[0]);
  $hl->header('create', 1, -itemtype => 'text', -text => "Date");
  $hl->columnWidth(1, -char => $widths[1]);
  $hl->header('create', 2, -itemtype => 'text', -text => "Old Date");
  $hl->columnWidth(2, -char => $widths[2]);
  $hl->header('create', 3, -itemtype => 'text', -text => "Type");
  $hl->columnWidth(3, -char => $widths[3]);

  &update_datelist($hl);
  return $hl;
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
  $ff->Label(-text => "PEN", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => "PTS", -width => 4)->pack(-side => 'left');
  $ff->Label(-text => "Rank", -width => 4)->pack(-side => 'left');
  $ff->pack(-side => 'top', -fill => 'x');

  # We have to go by the MAXIMUM number of teams that could play.
  foreach (my $x=1; $x <= $max_numteams; $x++) {
    my $ff = $f->Frame()->pack(-side => 'top', -fill => 'x');

    $ff->Label(-text => $x, -width => 2)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{TEAM}, -width => 20)->pack(-side => 'left');
    $standings{$x}->{TEAM} = $teams[$x];
    $ff->Label(-textvariable => \$standings{$x}->{W}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{T}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{L}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{F}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{C}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{GF}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{GA}, -width => 4)->pack(-side => 'left');
    $ff->Label(-textvariable => \$standings{$x}->{PCNT}, -width => 4)->pack(-side => 'left');
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

  my $date = shift;

  my %tmp;
  print "update_standings($date)\n";

  # Zero out the standings first
  &zero_standings(\%standings);
  &zero_standings(\%tmp);

  # Save the current week data back to @matches

  # FIXME!
  &save_curmatch($curdate);

  # Now go through all matches and figure out standings.
  foreach my $m (sort bydatetimefield @matches) {
    my $matchdate = $m->{"Date"};
    
    #print "m->{Type} = ", $m->{"Type"}, "\n";
    if ($m->{"Type"} eq "G" && &my_dtd($matchdate) <= &my_dtd($curdate)) {
      # Do we have full scores recorded for this match yet?
      if ($m->{"Complete"}) {
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
	  # reset scores and such...
	  #print "   HS: $m->{HomeScore}, AS: $m->{AwayScore}\n";
	  
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
    $tmp{$b}->{PTS} <=> $tmp{$a}->{PTS} ||
      $tmp{$b}->{W} <=> $tmp{$a}->{W} ||
	$tmp{$b}->{L} <=> $tmp{$a}->{L} ||
	  $tmp{$b}->{T} <=> $tmp{$a}->{T} ||
	    ($tmp{$b}->{GF} - $tmp{$b}->{GA}) <=> ($tmp{$a}->{GF} - $tmp{$a}->{GA});
  } keys %tmp) {
    #print "$idx  $teams{$idx}   $tmp{$idx}->{PTS}\n";
    foreach my $k (qw( W L T F C PTS GF GA RANK)) {
      $standings{$x}->{$k} = $tmp{$idx}->{$k};
    }
    $standings{$x}->{TEAMNUM} = $idx;
    $standings{$x}->{TEAM} = $teams[$idx];
    $x++;
  }
}

#---------------------------------------------------------------------
# Save the current info in %curmatch back to the @match array.
sub save_curmatch {
  my $date = shift;
  
  print "save_curmatch($date)\n";

  # Save current week data....
  my $idx = 1;
  foreach my $m (sort bydatetimefield @matches) {
    if ($m->{"Date"} eq "$date") {
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
# Returns 1 if all matches in a week are complete, 0 otherwise.  

sub all_matches_complete {

  my $week = shift;
  my $complete;

  # This is inefficient, we should have a data structure tracking
  # this info instead.  Maybe when we go object oriented?

  # How about a counter called 'completed' which would be quicker to check?

  foreach my $m (sort bydatetimefield @matches) {
    # We only care about $week, so skip any others, and return the
    # results once we find the right week.

    if ($m->{"Week"} == $week) {
      $complete = 0;
      for (my $i=1; $i <= $matches_per_week; $i++) {
	$complete = $complete + $m->{"Complete"};
      }
      if ($complete == $matches_per_week) {
	return 1;
      }
      return 0;
    }
  }
  return 0;
}

#---------------------------------------------------------------------
sub clear_match_display {

  # Empty the Home and Away columns first, we have multiple matches per-week.
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
    $curmatch{$i}->{"Type"} = "";
    &chgcolor($notokcolor,$i);
  }
}

#---------------------------------------------------------------------
# Load the current match hash $curmatch with data, 

sub load_curmatch {
  my $date = shift;

  print "load_curmatch($date)\n";

  &clear_match_display;

  # Fill in the $curmatches with the proper match info
  my $curidx = 1;
  foreach my $m (sort bydatetimefield @matches) {
    if ($m->{"Date"} eq "$date") {
      $curmatch{$curidx}->{"HomePoints"} = $m->{"HomePoints"};
      $curmatch{$curidx}->{"HomeScore"} = $m->{"HomeScore"};
      $curmatch{$curidx}->{"HomeCoed"} = $m->{"HomeCoed"};
      if ($m->{"Home"} =~ m/^\d+$/) {
	$curmatch{$curidx}->{"HomeName"} = $teams[$m->{"Home"}];
	$curmatch{$curidx}->{"AwayName"} = $teams[$m->{"Away"}];
      }
      else {
	$curmatch{$curidx}->{"HomeName"} = $m->{"Home"};
	$curmatch{$curidx}->{"AwayName"} = $m->{"Away"};
      }      

      $curmatch{$curidx}->{"AwayPoints"} = $m->{"AwayPoints"};
      $curmatch{$curidx}->{"AwayScore"} = $m->{"AwayScore"};
      $curmatch{$curidx}->{"AwayCoed"} = $m->{"AwayCoed"};
      
      $curmatch{$curidx}->{"Time"} = $m->{"Time"};
      $curmatch{$curidx}->{"Field"} = $m->{"Field"};
      $curmatch{$curidx}->{"Week"} = $m->{"Week"};
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
  my $new_date = shift;

  print "update_scores($new_date)  curdate = $curdate\n";
  my $new_week;
    
  if ("$curdate" ne "$new_date") {
    my $curidx;
    $new_week = join("-", &date2week($new_date));
    
    &save_curmatch($curdate);
    
    &load_curmatch($new_date);
    # Reset the Current Week finally.
    $curdate = $new_date;
    &update_standings($curdate);
    # Require a save if we're exiting...
    $NeedSave = 1;
  }
}

#---------------------------------------------------------------------
# Builds the headers to the frame where scores are entered/updated.
# Uses a global (bad!) $curmatch which holds N matches per-week.  The
# values are saved/loaded as the week window is changed to reflect
# which week we are working on.  How to make this more object
# oriented in a clean way? 
#
# For now, just make the frame big enough for one match per-week which
# is the minimum, then return a pointer so we can add/delete widgets
# when we load/initialize new schedules.  

sub init_scores {
  my $top = shift;
  
  my $hf = $top->Frame;
    
  # Headers
  
  $hf->Label(-text => "Time", -width => 6)->pack(-side => 'left');
  $hf->Label(-text => "Field", -width => 8)->pack(-side => 'left');
  $hf->Label(-text => "Home", -anchor => 'w', -width => 20)->pack(-side => 'left');
  $hf->Label(-text => "Score", -width => 8)->pack(-side => 'left');
  $hf->Label(-text => "Coed", -width => 4)->pack(-side => 'left');
  $hf->Label(-text => "Points", -width => 7)->pack(-side => 'left');
  
  $hf->Label(-text => "vs", -width => 8)->pack(-side => 'left');
  
  $hf->Label(-text => "Away", -anchor => 'w', -width => 20)->pack(-side => 'left');
  $hf->Label(-text => "Score",-width => 8)->pack(-side => 'left');
  $hf->Label(-text => "Coed",-width => 4)->pack(-side => 'left');
  $hf->Label(-text => "Points",-width => 6)->pack(-side => 'left');
  $hf->pack(-side => 'top', -fill => 'x');
  
  $top->pack(-side => 'top', -fill => 'x');
}

#---------------------------------------------------------------------
# Setup the actual scores in the frames.  

sub setup_scores {
  my $top = shift;
  my $num_matches = shift;

  foreach (my $m=1; $m <= $num_matches; $m++) {
    my $f = $top->Frame;
    my $w;
    
    $f->Label(-textvariable => \$curmatch{$m}->{"Time"}, -width => 6)->pack(-side => 'left');
    $f->Label(-textvariable => \$curmatch{$m}->{"Field"}, -width => 8)->pack(-side => 'left');
    $f->Label(-textvariable => \$curmatch{$m}->{HomeName}, -anchor =>
	      'w', -width => 20)->pack(-side => 'left');
    $f->BrowseEntry(-label => '',
		    -variable => \$curmatch{$m}->{"HomeScore"},	
		    -width => 3,
		    -listwidth => 20,
		    -choices => \@scores,
		    -browsecmd => [ \&computepoints, $m,"Home" ],
		    # Only allow numbers or the letter F to be entered
		    -validate => 'key',
		    -validatecommand => sub { $_[0] =~ m/^(?:|F|\d+)$/; },
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
    $f->BrowseEntry(-label => '',
		    -variable => \$curmatch{$m}->{"AwayScore"},	
		    -width => 3,
		    -listwidth => 20,
		    -choices => \@scores,
		    -browsecmd => [ \&computepoints, $m,"Home" ],
		    # Only allow numbers or the letter F to be entered
		    -validate => 'key',
		    -validatecommand => sub { $_[0] =~ m/^(?:|F|\d+)$/; },
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
# If $comp is 0, we remove all highlighting for the week at once, but
# if it's 1, we need to check the other matches in $week and make sure
# they are all Complete before we turn on highlight.

sub chg_datelist_status {
  my $week = shift;
  my $comp = shift;
  
  print "chg_datelist_status($week,$comp)\n";
  
  my $dls_clear = $match_datelist->ItemStyle('text', -background => $default_background);
  my $dls_comp = $match_datelist->ItemStyle('text', -background => 'lightgreen');

  my $e = 0;

  if ($comp) {
    # Make sure all matches for this week are complete first...
  }
  else {
    #$match_datelist->itemConfigure($e, 0, -style => $dls_clear);
  }
}

#---------------------------------------------------------------------
# Implements the rules of the league.  Could be make more generic with
# a rules configuration file at some point.  
#
# TODO: Needs to have magic constants pulled out and proper names
# applied.

sub computepoints {

  my $idx = shift;
  my $us = shift;

  #print "computepoints($idx,$us)\n";
  my ($ourscore,$ourcoed,$ourpts,$them,$theirscore,$theircoed);

  my $hs = $curmatch{$idx}->{"HomeScore"};
  my $hc = $curmatch{$idx}->{"HomeCoed"};
  my $as = $curmatch{$idx}->{"AwayScore"};
  my $ac = $curmatch{$idx}->{"AwayCoed"};
  
  #print "Scores:  $hs ($hc) : $as ($ac)\n";
  
  # Now we score the damn thing, big ugly state table...

  if ($hs eq "" and $as eq "")  {
    #print " Home and Away empty\n";
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"AwayPoints"} = 0;
    $curmatch{$idx}->{"Complete"} = 0;
    &chgcolor($notokcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},0);
    $NeedSave = 1;
  }
  elsif ($hs eq "" and $as =~ /\d+/) {
    #print " Home empty, Away scored.\n";
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"AwayPoints"} = 0;
    $curmatch{$idx}->{"Complete"} = 0;
    &chgcolor($notokcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},0);
    $NeedSave = 1;
  }	
  elsif ($as eq "" and $hs =~ /\d+/) {
    #print " Away empty, Home scored.\n";
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"AwayPoints"} = 0;
    $curmatch{$idx}->{"Complete"} = 0;
    &chgcolor($notokcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},0);
    $NeedSave = 1;
  }	
  # Double Forfeit = no points for anyone.
  elsif ($hs eq "F" and $as eq "F") {
    #print " Double Forfeit\n";
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"HomeCoed"} = 0;
    $curmatch{$idx}->{"AwayPoints"} = 0;
    $curmatch{$idx}->{"AwayCoed"} = 0;
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
  elsif ($hs eq "F" and $as =~ m/^$|\d+/) {
    #print " Home Forfeit.\n";
    $curmatch{$idx}->{"HomePoints"} = 0;
    $curmatch{$idx}->{"HomeCoed"} = 0;
    $curmatch{$idx}->{"AwayScore"} = "";
    $curmatch{$idx}->{"AwayPoints"} = 6 + $curmatch{$idx}->{"AwayCoed"};
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
  elsif ($as eq "F" and $hs =~ m/^$|\d+/) {
    #print " Away Forfeit.\n";
    $curmatch{$idx}->{"HomePoints"} = 6 + $curmatch{$idx}->{"HomeCoed"};
    $curmatch{$idx}->{"AwayPoints"} = 0;
    $curmatch{$idx}->{"AwayCoed"} = 0;
    $curmatch{$idx}->{"HomeScore"} = "";
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
  elsif ($hs > $as) {
    #print " Home Wins.\n";
    $curmatch{$idx}->{"HomePoints"} = 6 + $curmatch{$idx}->{"HomeCoed"};
    $curmatch{$idx}->{"AwayPoints"} = 2 + $curmatch{$idx}->{"AwayCoed"};
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
  elsif ( $hs == $as ) {
    #print " Tie.\n";
    $curmatch{$idx}->{"HomePoints"} = 4 + $curmatch{$idx}->{"HomeCoed"}; 
    $curmatch{$idx}->{"AwayPoints"} = 4 + $curmatch{$idx}->{"AwayCoed"};
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
  elsif ( $hs < $as ) {
    #print " Away Wins.\n";
    $curmatch{$idx}->{"HomePoints"} = 2 + $curmatch{$idx}->{"HomeCoed"}; 
    $curmatch{$idx}->{"AwayPoints"} = 6 + $curmatch{$idx}->{"AwayCoed"};
    $curmatch{$idx}->{"Complete"} = 1;
    &chgcolor($okcolor,$idx);
    &chg_datelist_status($curmatch{$idx}->{"Week"},1);
    $NeedSave = 1;
  }
}

#---------------------------------------------------------------------
sub parseopts {
  
  #&debug("parseopts()\n");

  GetOptions(
	     'D:i'   => \$DEBUG,
	     'f=s'   => \$game_file,
	     'h'     => \$prog_help,
	     'r'     => \$do_report,
	    ) or pod2usage(2);

  pod2usage(2) if ($#ARGV < -1);
  pod2usage(1) if $prog_help;
  pod2usage(-exitstatus => 0, -verbose => 2) if $man;
}

#---------------------------------------------------------------------
sub setup_master_menu {

  my $top = MainWindow->new(-class => 'TkScore');
  $top->configure(-title => "No game file loaded",
		  -height => 200,
		  -width => 400,
		 );
  $top->geometry('-300-300');
  
  # Default font.  
  $top->optionAdd('*font', $default_font);
  
  # Use this to set default colors.  
  $top->optionAdd('*TkScore*background', $default_background);
  
  # Menu Bar of commands
  my $mbar=$top->Menu();
  $top->configure(-menu => $mbar);
  my $m_season=$mbar->cascade(-label=>"~Season", -tearoff => 0);

  #---------------------------------------------------------------------
  # Season Menu
  $m_season->command(-label => '~New     ', -command => sub { 
		       &season_new($top); },
		    );
  $m_season->command(-label => '~Open    ', -command => sub {
		       &season_open($top,$game_file);
		     },
		    );
  $m_season->separator();
  $m_season->command(-label => '~Quit    ', -command => sub{ 
		       &cleanup_and_exit($top,$game_file)},
		    );

  return $top;
}

#---------------------------------------------------------------------
# Set the report filename based on our game_file name.
$rpt_file = $game_file;
$rpt_file =~ s/\.tks$//;

#---------------------------------------------------------------------
# If asked to generate a report, don't setup the windows at all.  
#---------------------------------------------------------------------

# Parse command line options.
&parseopts;

my $top = &setup_master_menu;

# Load the game file and generate a report if asked.
if ($game_file && $do_report) {
  &season_load_file($top,$game_file);
  &make_report();
  &Tk::exit;
}

#---------------------------------------------------------------------
# MAIN

&MainLoop;

__END__

=head1 tk-score

=head1 SYNOPSIS

tk-score [options] 

  Options:
     -D [#]                debugging
     -f <file>             which .tks season file to load
     -h                    this help
     -v                    verbose
     
=head1 OPTIONS

=over 4

=item B<-f file>

Tells which .tks file holding a season to load.

=back

=head1 DESCRIPTION

B<tk-score> is a tool to help manage and score a soccer (football)
league over a season.  

=cut

=head1 Design Notes

2013/11/06 

=item Should be moving to a more Object Oriented setup.  Should have a
single season instance ($season = TKS::Season::New?) which can then load/save info.

To update various things, you would use the contstructors for matches,
standings, rosters, teams, etc.

  =item TKS::Team, TKS::Match, TKS::Roster  should all be modules.

=cut

2014/03/17

=item Instead of Weeks and Now dates as accessor for matches, we
should probably use a unique MatchID value for each match, then we can
sort by date and return MatchID(s) for a date, and then index into the
master list of @matches using that value.  Simpler and easier and more
efficient.  

=item Match Type will be one of:

=over 2
=item Scrimmage: S
=item Match: G
=item Playoff: P
=item Makeup: M

=item Playoff/Makeup: PM, used when we have a three round playoff
scheme, but might need to reschedule.  
=back


=head1 AUTHOR

John Stoffel
john@stoffel.org

