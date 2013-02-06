package Transaction::Options;

use Modern::Perl;
use Moose;
use Method::Signatures;
use Getopt::Long;
use Pod::Usage;
use Pod::Find qw(pod_where);
use Data::Dumper;

has port => (isa => 'Int', is => 'rw');
has verbose => (isa => 'Bool', is => 'rw');
has debug => (isa => 'Bool', is => 'rw');

sub BUILD {
	my $self = shift;
	my ($help, $verbose, $port, $debug) = (0, 0, 0, 0);
	GetOptions(
		verbose => \$verbose,
		debug => \$debug,
		"help|?" => \$help,
		"port=s" => \$port,
	);

	pod2usage(-input => pod_where({-inc => 1}, __PACKAGE__)) 
		if $help;
	
	$self->port($port) if $port;
	$self->verbose($verbose) if $verbose;
	$self->debug($debug) if $debug;
}

1;

__END__

=head1 SYNOPSIS

trn-start.pl [options]

	Options:
		-help		brief help message
		-port		Port to use
		-debug		Run in debug mode
		-verbose	Run in verbose mode


=cut
