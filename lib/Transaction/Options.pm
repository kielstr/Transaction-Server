package Transaction::Options;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use Getopt::Long;
use Pod::Usage;
use Pod::Find qw(pod_where);
use vars qw($AUTOLOAD);
use Data::Dumper;

sub new {
	my ($self, %args) = @_;
	$self = bless {}, $self;
	$self->raw_argv(\@ARGV);

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
	my $data = \%{Transaction::_data};
	if (my $val = shift) {
		$data->{OPTIONS}{uc $attr} = $val;
	}
	
	return (exists $data->{OPTIONS}{uc $attr}) ? $data->{OPTIONS}->{uc $attr} : undef;  
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
