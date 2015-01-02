#!/usr/bin/perl -w

# Initial stab at OO tk-score modules to make handing crap simpler.

package Match;

sub new {
  my $class = shift;
  my $self = {
	      Week => 0,
	      Date => '',
	      Time => '',
	      Field => '',
	      Home => 0,
	      Away => 0,
	      HomeScore => "",
	      HomeCoed => 0,
	      HomePoints => 0,
	      AwayScore => "",
	      AwayCoed => 0,
	      AwayPoints => 0,
	      Complete => 0,
	      Type => '',
	     };
  
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

1;
