package Transaction::Options;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use Getopt::Long;
use Pod::Usage;
use Pod::Find qw(pod_where);
use vars qw($AUTOLOAD);
use Data::Dumper;

my %_data;
sub new {
	my ($self, %args) = @_;
	$self = bless {}, $self;
	
	$_data{refaddr $self} = {map {uc $_ => $args{$_}} keys %args};

	my ($help, $verbose, $port, $debug) = (0, 0, 0, 0);
	GetOptions(
		verbose => \$verbose,
		debug => \$debug,
		"help|?" => \$help,
		"port=s" => \$port,
	);

	pod2usage(-input => pod_where({-inc => 1}, __PACKAGE__)) if ($help);
	
	$self->port($port) if $port;
	$self->verbose($verbose) if $verbose;
	$self->debug($debug) if $debug;
	return $self;
}

sub AUTOLOAD {
	my $self = shift;
	(my $attr = $AUTOLOAD)=~ s/.*:://;
	if (my $val = shift) {
		$_data{refaddr $self}->{uc $attr} = $val;
	}
	
	return (exists $_data{refaddr $self}->{uc $attr}) ? $_data{refaddr $self}->{uc $attr} : undef;  
}

1;

__END__

=head1 SYNOPSIS

trn-start.pl [options] [file ...]

	Options:
		-help		brief help message
		-port		Port to use
		-debug		Run in debug mode
		-verbose	Run in verbose mode


=cut
