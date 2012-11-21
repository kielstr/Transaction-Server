package Transaction::Param;

use strict;
use warnings;
use vars qw($AUTOLOAD);

sub new {
	my $self = shift;
	bless {}, $self;
}

sub AUTOLOAD {
	my ($self, $val) = @_;
	(my $attr = $AUTOLOAD) =~ s/.*:://;
	if ($attr and exists $self->{_param}{$attr}) {
		return $self->{_param}{$attr};
	} elsif ($attr and $val) {
		$self->{_param}{$attr} = $val;
	}
}

1;
