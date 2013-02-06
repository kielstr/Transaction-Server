package Transaction::Config;
# Work out how to use Moose in this module problem is the autoloading 
# of config values.

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use XML::Simple;
use Carp;
use FindBin qw($Bin);
use vars qw($AUTOLOAD);
use Data::Dumper;

my %_data;
sub new {
	my ($self, %args) = @_;
	my %cfg = map {uc $_ => $args{$_}} keys %args;
	$self = bless {}, $self;
	$self->_init;
	return $self; 
}

sub _init {
	my $self = shift;
	my %file_locations = (
		1 => "$Bin/etc/config.xml",
		2 => '/etc/trnd/config.xml',
		3 => '/usr/local/etc/trnd/config.xml'
	);
	
	my ($filename) = map {(-e $file_locations{$_}) 
		? $file_locations{$_} : ()} sort keys %file_locations;

	my $xml = XMLin($filename);
	my $server = $xml->{server};
	my $webUI = $xml->{server};
	$self->port($$server{port});
	
	for my $val (keys %$server) {
		$self->$val($$server{$val});
	}

	# need to sort out the config hash ... grouped by server webUI
	#for my $val (keys %$webUI) {
	#	$self->$val($$webUI{$val});
	#}

	#my $data = \%Transaction::_data;
	#print Dumper $$data{CONFIG};
	return 1;
}

sub AUTOLOAD {
	my $self = shift;
	(my $attr = $AUTOLOAD)=~ s/.*:://;
	
	my $data = \%Transaction::_data;
	if (my $val = shift) {
		$$data{CONFIG}{uc $attr} = $val;
	}
	return (exists $$data{CONFIG}{uc $attr}) ? $$data{CONFIG}{uc $attr} : undef;
}

1;
