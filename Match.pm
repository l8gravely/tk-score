#!/usr/bin/perl -w

# Initial stab at OO tk-score modules to make handing crap simpler.

package Match;

sub new {
  my $class = shift;
  my $self = {
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
