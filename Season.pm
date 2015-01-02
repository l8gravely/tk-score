#!/usr/bin/perl -w

# Initial stab at OO tk-score modules to make handing crap simpler.

package Season;

sub new {
  my $class = shift;
  my $top = shift;

  my $mw = MainWindow->new(-class => 'TkScoreSeason');
  my $self = {
	      top = $mw,
	      Match_Cur = {},
	      Matches = [],
	      Teams = [],
	      Schedule = { },
	      Game_file = "",
	      File_Version = "v2.0",
	     };

  $mw->configure(-title => "Season Window",
		-height => 400,
		-width => 1000,
		);

  bless $self, $class;
  return $self;
}

sub setvar {
    my ( $self, $var, $val ) = @_;
    $self->{$var} = $val if defined($val);
    return $self->{$var};
  }

sub getvar {
    my( $self, $var ) = @_;
    return $self->{$var};
  }


#---------------------------------------------------------------------
sub load_season_file {
  my ($self, $file) @_;

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

# ---------------------------------------------------------------------
# We now only setup this season menu in a new top window when we
# actually do a new season, or load a season.  This is so we have a
# place to hang off the main $season blessed variable which holds all
# the pointers to data and such we need.

sub setup_season_menu {
  my $top = MainWindow->new(-class => 'TkScore');
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
  $m_season->command(-label => '~New     ', -command => sub { 
		       &init_new_season($top); },
		    );
  $m_season->command(-label => '~Open    ', -command => sub {
		       &select_season_file($top,$game_file);
		     },
		    );
  $m_season->command(-label => 'Edit    ', -command => [ \&edit_season, \%season ],);
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
  $m_season->command(-label => '~Quit    ', -command => sub{ &cleanup_and_exit($top,$game_file)},
		    );
  
  #---------------------------------------------------------------------
  # Match Menu
  $m_match->command(-label => 'Reschedule', -command => sub {
		      &match_reschedule($top,$curdate);},
		   );
  
  #---------------------------------------------------------------------
  # Penalty Menu
  $m_penalty->command(-label => 'Add', -command => sub {
			&penalty_add($top,$curweek);},
		     );
  $m_penalty->command(-label => 'Edit', -command => sub {
			&penalty_edit($top,$curweek);},
		     );
  $m_penalty->command(-label => 'Remove', -command => sub {
			&penalty_del($top,$curweek);},
		     );
  
  #---------------------------------------------------------------------
  # Playoffs Menu
  $m_playoffs->command(-label => 'Setup', -command => sub {
			 &playoffs_setup($top,$curweek);},
		      );
  $m_playoffs->command(-label => 'Score', -command => sub {
			 &playoffs_score($top,$curweek);},
		      );
  $m_playoffs->command(-label => 'Report', -command => sub {
			 &playoffs_reports($top,$curweek);},
		      );
  
  
  #---------------------------------------------------------------------
  # Teams Menu
  $m_teams->command(-label => 'View', -command => [ \&teams_view, $top, \@teams ],);
  $m_teams->command(-label => 'Rename', -command => [ \&teams_rename, $top, \@teams ],);
  
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
    &load_season_file($game_file);
  }
}

1;
