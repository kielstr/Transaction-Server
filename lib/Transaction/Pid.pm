package Transaction::Pid;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use IO::File;
use Carp;
use Data::Dumper;

my %_data;

sub new {
	my ($self, %args) = @_;
	my %cfg = map {uc $_ => $args{$_}} keys %args;
	$self = bless {}, $self;
	$_data{refaddr $self} = \%cfg;
	return $self;
}

sub running {
	my $self = shift;
	my $runfile = $_data{refaddr $self}->{RUNFILE};
	if (-e $runfile) {
		my $fh = IO::File->new($runfile, 'r');
		croak "Can not open run file $runfile $!" unless defined $fh;
		chomp(my $pid = <$fh>);
		$fh->close;
		return $pid if $pid ne $$ and kill 0, $pid;
	}
	return 0;
}

sub create {
	my $self = shift;
	my $runfile = $_data{refaddr $self}->{RUNFILE};
	my $fh = IO::File->new($runfile, 'w');
	croak "Failed to create run file $runfile $!" unless defined $fh;
	print $fh "$$";
	$fh->close;	
}

sub DESTROY {
	my $self = shift;
	my $runfile = $_data{refaddr $self}->{RUNFILE};
	if (-r $runfile) {
		my $fh = IO::File->new($runfile, 'r');
		croak "Failed to open run file $runfile $!" unless defined $fh;
		chomp (my $pid = <$fh>);
		if ($pid eq $$) {
			unlink $runfile or die "Can not unlink run file $runfile $!";
		}
		undef $fh;
	}
}

1;
