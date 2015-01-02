#!/usr/bin/perl -w

# Initial stab at OO tk-score modules to make handing crap simpler.

package Schedule;

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


1;
