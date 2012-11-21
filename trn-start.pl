#!/usr/bin/perl -w

use strict;
use IO::Socket;
use IO::Select;
use IO::Handle;
use File::Pid;
use FindBin qw($Bin);
use lib "$Bin/lib";
use Transaction qw(trans_send trans_data);
use Transaction::Log qw(trans_log);
use Transaction::Sig;
use Data::Dumper;

use constant PORT => 5001;
use constant PID_NAME => 'trnd';

my %children;
Transaction::Sig->new(\%children, $0, $trn_log);

$0 = PID_NAME;

STDOUT->autoflush;
STDERR->autoflush;

my $trn_log = new Transaction::Log PID_NAME => PID_NAME;
my $pidfile = File::Pid->new({
	file => '/var/run/trn.pid'
});

$pidfile->write;

if (my $pid = $pidfile->running) {
	die "Already running: $pid" ;
}


my $select = new IO::Select;
my $server = IO::Socket::INET->new (
	LocalPort => PORT,
	Type => SOCK_STREAM,
	Reuse => 1,
	Listen => 10
) or die "Couldn't be a tcp server on port ". PORT .": $@\n";

$select->add($server);

$trn_log->log('notice', "Transaction server started ".scalar localtime);
while ($$) {
	for my $socket ($select->can_read(1)) {
		while (my $client = $socket->accept()) {

			if (my $child_pid = fork) {
				$children{$child_pid} = time;
			} else {

				print $client "Transaction Server v2.0\nready...\n";
		
				my $peer_address = $client->peerhost();
				my $peer_port = $client->peerport();
				$trn_log->log('notice', "Connection recieved from $peer_address:$peer_port");
				
				$0 = "trnd[$peer_address]";
						
				my $trn = new Transaction;
				$trn->client($client);
				$trn->peer_addr($peer_address);
				$trn->log($trn_log);
				
				while (my $buff = $client->getline) {
					my ($key, $val) = split '=', $buff;
					$key ||= $buff;
					$key =~ s/(^\s+)|(\s+$)//;
				
					close ($client) and last if $key eq 'quit';
					$trn->do if $key eq '.' and $trn->param('action') and $trn->auth_ok; 
								
					next unless $val;
					$val =~ s/(^\s+)|(\s+$)|\n+//;
					$trn->param($key=>$val);
				}
				close $client;
				exit;
			}
		}	
	}	
}

$pidfile->remove;
close $server;
