package Transaction;

use strict;
use warnings;
use IO::Socket;
use vars qw($AUTOLOAD @ISA @EXPORT_OK $users);
use FindBin qw($Bin);
use lib "$Bin/lib";
use Transaction::Param;
require Exporter;
use Data::Dumper;

@ISA = qw(Exporter);
@EXPORT_OK = qw(trans_data trans_send);

our %_data;
     
sub new {
	my $self = shift;
	$self = bless {}, $self;
	$self->load;
	$self;
}

sub load {
	my $self = shift;
	require "trans-action.pl";
	require "trans-access.pl"	
}

sub param {
	my ($self, $param, $val) = @_;

	if ($val) {
		$self->{_param}{$param} = $val;
		return 1;
	}

	if(wantarray() and not $param) {
		return keys %{$self->{_param}};
	}
	
	return unless $param and $self->{_param}{$param};
	return $self->{_param}{$param};
}
                                                        
sub client {
	my ($self, $client) = @_;
	$self->{_CLIENT} = $client if $client;
	$self->{_CLIENT};
}

sub log {
	my ($self, $trn_log) = @_;
	$self->{_LOG} = $trn_log if $trn_log;
	$self->{_LOG};
}

sub peer_addr {
	my ($self, $client) = @_;
	$self->{_PEER_ADDR} = $client if $client;
	$self->{_PEER_ADDR};
}

sub auth_ok {
	my $self = shift;
	my $peer_addr = $self->peer_addr;
	my $user = $self->param('user');
	my $password = $self->param('password');
	my $action = $self->param('action');

	my $logger = $self->log;
	my $data = \%{Transaction::_data};
	
	my $transaction = $data->{CONFIG}{TRANSACTION}{$action} or do {
			$self->data('error', '1003'); 
			$self->send;
			return 0;
	};
	
	my @allowed = split ',', $$transaction{allow};
	$self->_report_error('1004') and return 0
		unless grep /^$user$/, @allowed;
	
	my $access = $data->{CONFIG}{ACCESS};
	for my $client (@{$access->{client}}) {
		if ($user eq $client->{username} 
			and $password eq $client->{password} 
			and grep {$peer_addr eq $_} split ',', $client->{host}) {
			$logger->log('notice', "Authenticated user $user for transaction $action");
			return 1;			
		}
	}

	for my $href (@$users) {
		if ($user eq $href->{username} 
			and $peer_addr eq $href->{host} 
			and $action eq $href->{action} 
			and $password eq $href->{password}) {
			$logger->log('notice', "Authenticated user $user for transaction $action");
			return 1;	
		} 
	}

	$self->_report_error('1001');
	return 0;
}

sub run {
	my $self = shift;
	my $param = $self->{_param};
	my $action = $self->param('action');
	my $logger = $self->log;
	$logger->log('notice', "Processing transaction $action");
	
	$self->$action($self);
	$self->{_param} = {};
} 

{
	my $trn;
	sub trans_send {
		my $socket = shift;
		$trn = new Transaction unless defined $trn;
		
		$trn->client($socket);
		$trn->send;
	}

	sub trans_data {
		my ($socket, $key, $val) = @_;
		$trn = new Transaction unless defined $trn;
		$trn->client($socket);
		$trn->data($key, $val);
	
	}
}

sub data {
	my ($self, $key, $val) = @_;
	my $client = $self->{_CLIENT};
	$client->print("$key=$val\n");
}

sub send {
	my $self = shift;
	my $client = $self->{_CLIENT};
	$client->print(".\n") if $client;
}

sub start_server {
	my $self = shift;
	my $data = \%{Transaction::_data};
	my $options = $data->{OPTION};
	my $config = $data->{CONFIG};
	
	my $server = IO::Socket::INET->new (
		LocalPort => ($options->{PORT} ? $options->{PORT} : $config->{PORT}),
		Type => SOCK_STREAM,
		Reuse => 1,
		Listen => 10
	) or die "Couldn't be a tcp server on port ". ($options->{PORT} ? $options->{PORT} : $config->{PORT}) .": $@\n";
	$_data{SERVER}->{SOCKET} = $server;
	return $server;
}

sub AUTOLOAD {
	my $self = shift;
	(my $attr = $AUTOLOAD) =~ s/.*:://;
	
	print "Not a valid transaction $attr\n";
}

sub DESTROY {
	my $self = shift;
	my $socket = $_data{SERVER}->{SOCKET};
	$socket->close if defined $socket;
	return 1;
}

sub _report_error {
	my ($self, $error) = @_;
	$self->data('error', $error);
	$self->send;
}

1;
