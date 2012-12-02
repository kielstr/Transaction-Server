package Transaction::Client;

use strict;
use warnings;
use IO::Socket;

sub new {
	my ($self, %args) = @_;
	my %conf = map {uc $_ => $args{$_}} keys %args;
	$self = bless \%conf, $self;
	$self->connect;
	$self;
}

sub connect {
	my $self = shift;
	$self->{_SOCKET} = IO::Socket::INET->new (
		PeerAddr => $self->{HOST},
		PeerPort => $self->{PORT},
		Type => SOCK_STREAM
	) or die "Couldn't connect to server at $self->{HOST}:$self->{PORT}\n\t$@\n";	
}

sub send {
	my ($self, $user, $passwd, $action, %args) = @_;
	my $socket = $self->{_SOCKET};
	$socket->print("user=$user\n");
	$socket->print("password=$passwd\n");
	$socket->print("action=$action\n");
	$socket->print("$_=$args{$_}\n") for keys %args;
	$socket->print(".\n");
	$self->{_PARAM} = {};

	$self->read;
}

sub read {
	my $self = shift;
	my $socket = $self->{_SOCKET};
	while (my $buff = $socket->getline) {
		my ($key, $val) = split '=', $buff;
		$key ||= $buff;
		$key =~ s/(^\s+)|(\s+$)//;
		last if $key eq '.';
		next unless $val;
		$val =~ s/(^\s+)|(\s+$)|\n+//;
		$self->param($key=>$val);
	}
}

sub quit {
	my $self = shift;
	my $socket = $self->{_SOCKET};
	$socket->print("quit\n");
	close $socket;
}

sub param {
	my ($self, $key, $val) = @_;

	return keys %{$self->{_PARAM}}
		if wantarray;
	if ($key and $val) { 
		$self->{_PARAM}{$key} = $val;
	} elsif ($key) {
		return $self->{_PARAM}{$key};
	}
}


sub DESTROY {
	my $self = shift;
	my $socket = $self->{_SOCKET} if exists $self->{_SOCKET};
	$socket->close if defined $socket;
}

1;
