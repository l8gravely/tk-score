#!/usr/bin/perl -w

# Initial stab at OO tk-score modules to make handing crap simpler.

package Season;

use YAML qw(DumpFile LoadFile);
use Tk::FileSelect;
use Tk::FileDialog;

#---------------------------------------------------------------------
sub new {
  my $class = shift;

  my $top = MainWindow->new(-class => 'TkScoreSeason');
  my $self = {
	      TOP => $top,
	      Match_Cur => {},
	      Matches => [],
	      Teams => [],
	      Schedule => { },
	      Game_file => "",
	      File_Version => "v2.0",
	      NeedSave => 0,
	     };

  $top->configure(-title => "Season Window",
		-height => 400,
		-width => 1000,
		);

  bless $self, $class;
  return $self;
}

#---------------------------------------------------------------------
sub setvar {
    my ( $self, $var, $val ) = @_;
    $self->{$var} = $val if defined($val);
    return $self->{$var};
  }

#---------------------------------------------------------------------
sub getvar {
    my( $self, $var ) = @_;
    return $self->{$var};
  }


# ---------------------------------------------------------------------
# Exit and close this season window.

sub season_close {


}

#---------------------------------------------------------------------
sub season_open {
  my ($self,$file) = @_;

  my $top = $self->{TOP};
  my $fs = $top->FileSelect(
			    -filter => '*.tks',
			    -directory => $ENV{'CWD'},
			   );
  $fs->geometry("600x400");
  
  my $game_file = $fs->Show;
  
  if ($game_file && &_season_load_file($game_file)) {
    # Set window Title to game_file
    $top->configure(title => $game_file);
  }
  else {
    print "Error loading.  Look in _season_select_file()\n";
  }
}
  
# ---------------------------------------------------------------------
# We now only setup this season menu in a new top window when we
# actually do a new season, or load a season.  This is so we have a
# place to hang off the main $season blessed variable which holds all
# the pointers to data and such we need.

sub season_win_init {
  my ($self) = @_;

  my $top = MainWindow->new(-class => 'TkScore');
  $self->{TOP} = $top;
  $top->configure(-title => "No game file loaded",
		  -height => 400,
		  -width => 1000,
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
  my $m_match=$mbar->cascade(-label=>"~Match", -tearoff => 0);
  my $m_schedule=$mbar->cascade(-label=>"Schedule", -tearoff => 0);
  my $m_help=$mbar->cascade(-label =>"~Help", -tearoff => 0);
  
  #---------------------------------------------------------------------
  # Season Menu
  $m_season->command(-label => 'Edit    ', -command => [ \&season_edit, \%season ],);
  $m_season->command(-label => '~Save    ', -command => sub { 
		       &save_curmatch($curdate);
		       &save_season_file($top,$game_file,\@teams,\@matches,\%standings,\%season);
		     },
		    );
  $m_season->command(-label => '~Save As ', -command => sub { 
		       &save_curmatch($curdate);
		       $game_file = &save_season_file_as($top,$game_file,\@teams,\@matches,\%standings,\%season);
		     },
		    );
  $m_season->separator();
  $m_season->command(-label => '~Update Standings', -command => sub {
		       &update_standings($curdate) },
		    );
  $m_season->separator();
  $m_season->command(-label => '~Report  ', -command => sub {
		       &make_report($rpt_file,"YYYY-MM-DD") },
		    );
  $m_season->separator();
  $m_season->command(-label => '~Close    ', -command => sub{ &season_close($top,$game_file)},
		    );
  
  #---------------------------------------------------------------------
  # Match Menu
  $m_match->command(-label => 'Reschedule', -command => sub {
		      &match_reschedule($top,$curdate);},
		   );
  
  #---------------------------------------------------------------------
  # Schedule Menu
  $m_schedule->command(-label => 'View', -command => [ \&schedule_view, $top, @matches ],);
  
  #---------------------------------------------------------------------
  # Help Menu
  $m_help->command(-label => 'Version');
  $m_help->separator;
  $m_help->command(-label => 'About');
  
  # Scores are up top, Week display and standings below, side by side.
  
  my $scoreframe=$top->Frame(-border => 2, -relief => 'groove', -height => 100);
  &init_scores($scoreframe);
  #&update_scores($curdate);
  $scoreframe->pack(-side => 'top', -fill => 'x');
  
  my $bottomframe = $top->Frame();
  
  my $datesframe = $bottomframe->Frame(-border => 2, -relief => 'groove');
  $match_datelist = &init_datelist($datesframe);
  $datesframe->pack(-side => 'left', -fill => 'y');
  
  my $standingsframe = $bottomframe->Frame(-border => 2, -relief => 'groove');
  &init_standings($standingsframe);
  $standingsframe->pack(-side => 'right', -fill => 'y');
  
  $bottomframe->pack(-side => 'top', -fill => 'x');
  
  
  if ($game_file ne "") {
    $top->configure(title => $game_file);
    &season_load_file($game_file);
  }
}

#---------------------------------------------------------------------
sub season_edit {
  
}

#---------------------------------------------------------------------
sub season_create {
  my ($self) = @_;
  
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
# Takes input from the "Setup a new Season" window and generates a
# schedule which you need to approve.  FIXME: add summary and approval window.

sub _sched_generate {
  my ($self) = @_;

  # Validate inputs.  Should be in the Setup a New Season window, with
  # the 'Done' button disabled until all the required info is entered.

  print "_sched_generate()\n";
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

sub _sched_accept {

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
# Need to check the return value here and NOT exit if we cancel the
# save. 

sub _season_save_file_as {
  my ($self,$file) = @_;
  my $top = $self->{TOP};

  $file = "new-season.tks"  if ($gf eq "");
  print "($file, .... )\n";

  my $fs = $top->FileSelect(-directory => '.',
			    -filter => "*.tks",
			    -verify => ['!-d'],
			    -initialfile => $file,
	);
  $fs->geometry("600x400");
  my $savefile = $fs->Show;

  if ($savefile eq "") {
    print "Not saving file: $savefile\n";
    return $file;
  }
  else {
    if (!($savefile =~ m/^.*\.tks$/)) {
      $savefile .= ".tks";
    }  
    
    if (&write_season_file($savefile,$teamref,$matchref,$standingsref,$seasonref)) {
      # Update our base report file name
      $rpt_file = $savefile;
      $rpt_file =~ s/\.tks$//;
      $top->configure(title => $savefile);
      return $savefile;
    }
    else {
      return undef;
    }
  }
}

#---------------------------------------------------------------------
# double check we've got a valid game file to save to first...
sub _season_save_file {
  my ($self,$file) = @_;
  my $top = $self->{TOP};

  print "_season_save_file($file)\n";
  if ($file eq "") {
    $file = $self->_season_save_file_as($file);
    if ($file eq "") {
      # Some sort of error handling here...
    }
  }
  else {
    $self->_season_write_file($file);
  }	
}

#---------------------------------------------------------------------
# FIXME - better error handling needed here!

sub _season_write_file {
  my ($self,$file) = @_;

  print "write_season_file($file, .... )\n";

  # We could purge $matches[#]->{DTD} but we unconditionally re-create
  # it on load, so that's ok. 

  my $data = { Teams => $teamref,
	       Matches => $matchref,
	       Standings => $standingsref,
	       Season => $seasonref,
	       Version => $gf_version,
	     };
  
  if (! -e $file) {
    # FIXME - again error handling...
  }
  DumpFile($file,$data);
  $self->{NeedSave} = 0;
}

#---------------------------------------------------------------------
sub _season_load_file {
  my $file = shift;

  my $matchid = 0;
  my %matchids;
  if (-f $file) {
    my $data = LoadFile($file);
    
    # Needs better error checking here!  We really only need the list
    # of teams and the matches to rebuild every thing else we use. 

    my $mpw = $data->{Matches_per_week};

    @teams = @{$data->{Teams}};
    @matches = @{$data->{Matches}};

    # Data Sanity checks and optimizations
    foreach my $m (@matches) {
      # Make sure all dates are in the correct format:
      if (defined($m->{"DateOrig"}) && $m->{"DateOrig"} ne "") {
	$m->{"DateOrig"} = &fix_week_date_fmt($m->{"DateOrig"});
      }
      if ($m->{"Date"} ne "") {
	$m->{"Date"} = &fix_week_date_fmt($m->{"Date"});
	# Hopeful optimization when sorting the matches
	$m->{"DTD"} = &my_dtd($m->{"Date"});
      }
      
      # Look for MatchID, if not found, add it.
      if (!defined($m->{"MatchID"})) {
	$m->{"MatchID"} = $matchid;
	$matchids{$matchid}++;
	$matchid++;
      }
      else {
	my $tmatchid = $m->{"MatchID"};
	if (defined $matchids{$tmatchid}) {
	  die "Error!  We have duplicated MatchIDs in $file\n\n";
	}
	else {
	  $matchids{$tmatchid}++;
	}
      }    

      # Look for Type, if not found assume "G" for Game.
      if (!defined($m->{"Type"})) {
	$m->{"Type"} = "G";
      }

    }

    # Build the @match_dates array so we can quickly get our data,
    # this will replace the $curweek index soonish
    my $found = "";
    undef @match_dates;
    foreach my $m (sort bydatetimefield @matches) {
      if ($m->{Date} ne "$found") { 
	push @match_dates, $m->{Date}; 
      }
    }

    # Update the week display maybe?
    &setup_scores($frame, $mpw);
    &load_curmatch($match_dates[0]);
    &update_datelist($match_datelist);
    &update_standings($match_dates[0]);
    
    # Update the rptfile name
    $rpt_file = $file;
    $rpt_file =~ s/\.tks$//;
    
    # Reset global default game_file
    $game_file = $file;

    return 1;
  }
  # Error, no file to load or some other error.  Needs Cleanup.
  return 0;
}

#---------------------------------------------------------------------
# Routines for TEAMs
#---------------------------------------------------------------------

#---------------------------------------------------------------------
sub teams_view {

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
# Report generation routines.
#---------------------------------------------------------------------
sub _rpt_results {
  my $date = shift;
  my $fh = shift;
  
  print " mk_results_rpt($date,FH)\n";

  my $week = &date2week($date);
  my ($h, $hc, $hs);
  my ($a, $ac, $as);

  my $ws = "$week ($date)";

  $^L = "";   # Turn off outputting formfeed when we get to a new page.
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
sub _rpt_standings {
  my $date = shift;
  my $fh = shift;

  print " mk_standings_rpt($date,FH)\n";

  my ($n, $team, $w, $t, $l, $f, $c, $gf, $ga, $pen, $pts, $d);
  my $week = &date2week($date);

  $d = "$week ($date)";

format STANDINGS_TOP =

  Standings after Week @<<<<<<<<<<<<<<<<
                       $d                       

      # Team               W   T   L   F   C   GF   GA  P  Pts
      - ----------------- --- --- --- --- --- ---  --- --  ---
.

format STANDINGS =
      @ @<<<<<<<<<<<<<<<< @>> @>> @>> @>> @>> @>>  @>> @>  @>>
    $n,$team,           $w, $t, $l, $f, $c, $gf, $ga, $pen, $pts
.

  $fh->format_name("STANDINGS");
  $fh->format_top_name("STANDINGS_TOP");
  $fh->autoflush(1);
  $fh->format_lines_left(0);

  &update_standings($date);
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
	$pen  = $standings{$i}->{PCNT} || 0;
        $pts  = $standings{$i}->{PTS};

        write $fh;
  }  
}

#---------------------------------------------------------------------
sub _rpt_penalties {
  my $curweek = shift;
  my $fh = shift;

  print " mk_penalties($week,FH)\n";

  # Take hash of penalties per-team and convert into a date/team
  # sorted list.
  my @penalties;

  foreach my $m (sort bydatetimefield @matches) {
	my $matchweek = $m->{"Week"};
	if ($matchweek <= $curweek) {
	  
	}
  }

}

#---------------------------------------------------------------------
sub _rpt_notes {
  my $fh = shift;

  print " mk_notes(FH)\n";

  print $fh "\n\n";
  print $fh "  Notes:\n";
  print $fh "\n\n";
}

#---------------------------------------------------------------------
# TODO - fix game start time in reports, use $curdate instead of $curweek.

sub _rpt_schedule {
  my $date = shift;
  my $fh = shift;

  print " mk_schedule_rpt($date,<FH>)\n";

  my ($time, $field, $home,$away);

  my $week = &date2week($curdate);
  print "  Weekdate = $date ($week)\n";

  my $nextweekdate = &get_next_match_date($date);
  my $nextweek = &date2week($nextweekdate);
  print "  Next date = $nextweekdate ($nextweek)\n";

  # TODO: Fix lookup of who is lining (if any) fields
  my $line_this_week = $lining_team{$week} || "<unknown>";
  my $line_next_week = $lining_team{$nextweek} || "<unknown>";

format SCHEDULE_TOP = 

  Schedule: @<<<<<<<<<<<<<<
             $nextweekdate

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

  # Should not print anything if $nextweekdate is ""
  foreach my $m (sort bydatetimefield @matches) {
    if ($m->{"Date"} eq $nextweekdate) {
      $time = $m->{"Time"};
      $field = $m->{"Field"};
      $home = $teams[$m->{"Home"}];
      $away = $teams[$m->{"Away"}];
      write $fh;
    }
  }

format LINING_TOP =
.

format LINING =

  Lining:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
           $line_this_week;
           @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
           $line_next_week;


.

  if ($dolining) {
    print "Showing Lining in report...\n";
    $fh->format_name("LINING");
    $fh->format_top_name("LINING_TOP");
    $fh->autoflush(1);
    $fh->format_lines_left(0);
    write $fh;
  }
}

#---------------------------------------------------------------------
sub _rpt_key {
  my $fh = shift;

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
# Make the weekly report, save it to a base file name passed in,
# adding in the date of week in YYYY-MM-DD format, or week-##
# depending on how called.

sub report_generate {
  my $base_rpt_file = shift;
  my $ext = shift;

  print "report_generate($base_rpt_file , $ext)\n";

  # Strip off .rpt if it exists.
  $base_rpt_file =~ s/\.rpt$//;

  my $week_date;
  my $file = "$base_rpt_file";
  if ($ext eq "YYYY-MM-DD") {
    my ($m,$d,$y) = split('/',$curdate);
    $file = $base_rpt_file . "-". sprintf("%04s-%02s-%02s",$y,$m,$d);
    print "  ext = YYYY-MM-DD, file = $file\n";
  }
  elsif ($ext eq "WEEK-##") {
    $file = "$base_rpt_file". "-$curweek";
    print "  ext = WEEK-##, file = $file\n";
  }
  
  $file .= ".rpt";
  
  if (!open(RPT, ">$file")) {
    warn "Error writing week $curweek report to $file: $!\n";
  }  
  else {
    &_rpt_results($curdate,\*RPT);
    &_rpt_standings($curdate,\*RPT);
    # TODO
    # &_rpt_penalties($curdate,\*RPT);
    &_rpt_notes(\*RPT);
    &_rpt_schedule_rpt($curdate,\*RPT);
    &_rpt_key(\*RPT);
    close RPT;
    
    print "\nWrote game report to: $file\n";
  }
}

#---------------------------------------------------------------------
sub schedule_view {
	
  print "schedule_view()\n";
  
    foreach my $m (sort bydatetimefield @matches) {
      my $week = $m->{"Week"};
      my $weekdate = &week2date($week);
      my $time = $m->{"Time"};
      my $field = $m->{"Field"};
      my $home = $teams[$m->{"Home"}];
      my $away = $teams[$m->{"Away"}];
      printf("%2d %14s  %3s  %7s    %-20s - %20s\n",$week, $weekdate, $time, $field, $home, $away);
    }
}

#---------------------------------------------------------------------
# MATCH handling routines
#---------------------------------------------------------------------
# Save the current info in %curmatch back to the @match array.
sub _save_curmatch {
  my ($self, $date) = @_;
  
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




1;
