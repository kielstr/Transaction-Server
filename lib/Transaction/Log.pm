package Transaction::Log;

use strict;
use warnings;
use vars qw($AUTOLOAD @ISA @EXPORT_OK);
use Sys::Syslog qw(:DEFAULT setlogsock);
require Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw(trans_log);

sub new {
	my ($self, %args) = @_;
	my %conf = map {uc $_ => $args{$_}} keys %args;
	$self = bless \%conf, $self;
	$self->init;
	$self;
}

sub init {
	my $self = shift;
	my $pid_name = $self->pid_name;
	setlogsock('unix');
	openlog("$pid_name\[$$]", 'ndelay', 'user');

}
sub trans_log {
	Transaction::Log->log(@_);
}

sub log {
	my ($self, $priority, $format, @args) = @_;
	syslog($priority, $format, @args);
}

sub AUTOLOAD {
	my ($self, $val) = @_;
	(my $attr = $AUTOLOAD) =~ s/.*:://;
	if ($attr and exists $self->{uc $attr}) {
		return $self->{uc $attr};
	} elsif ($attr and $val) {
		$self->{uc $attr} = $val;
	}
}

sub DESTORY {
	closelog;
}
1;
