#!/usr/bin/perl -w

use Modern::Perl;
use IO::Select;
use IO::Handle;
use IO::Pipe;
use FindBin qw($Bin);
use lib "$Bin/lib";
use autobox::Core;

use Transaction qw(trans_send trans_data);
use Transaction::Log qw(trans_log);
use Transaction::Sig;
use Transaction::Pid;
use Transaction::Options; 
use Transaction::Config;
use Transaction::WebUI;
use Transaction::Command;
use Data::Dumper;

use constant PID_NAME => "trnd @ARGV";

my $trn = Transaction->new;
my $config = Transaction::Config->new;
my $options = Transaction::Options->new;

fork and exit unless $options->debug;

STDOUT->autoflush;
STDERR->autoflush;

my $trn_log = new Transaction::Log PID_NAME => PID_NAME;
my $pidfile = Transaction::Pid->new;

if (my $pid = $pidfile->running) {
	die "Already running: $pid" ;
}

$pidfile->create;

my %children;

Transaction::Sig->new(
	#children_pids => \%children,
	pidname => $0, 
	trn_log => $trn_log
);

$0 = PID_NAME;

my $select = new IO::Select;
my $server = $trn->start_server;
my $pipe = new IO::Pipe;
my $webUI = Transaction::WebUI->new;

if (my $child_pid = fork) {
	$pipe->reader;
	$pipe->autoflush;
	
	$children{nowait}{$child_pid} = time;
} else {
	$pipe->writer;
	$pipe->autoflush;

	$0 = PID_NAME . "[WebUI]";
	$webUI->run($pipe);
}

$select->add($pipe);
$select->add($server);

$trn_log->log('notice', "Transaction server started ".scalar localtime);
while ($$) {
	for my $fh ($select->can_read(1)) {

		# Commands from the webUI
		if ($fh == $pipe) {
			my $cmd = Transaction::Command->new;
			while (my $buff = $pipe->getline) {
				my ($key, $value) = split '=', $buff;
				$key->chomp if $key;
				$value->chomp if $value;
				
				last if $key eq '.';
				$cmd->param($key, $value);

			}
			
			$cmd->execute;
			next;
		}

		# Client on socket;
		while (my $client = $fh->accept()) {
			if (my $child_pid = fork) {
				$children{wait}{$child_pid} = time;
			} else {
				
				print $client "Transaction Server v2.0\nready...\n";
		
				my $peer_address = $client->peerhost();
				my $peer_port = $client->peerport();
				$trn_log->log('notice', "Connection recieved from $peer_address:$peer_port");
				print "Connection recieved from $peer_address:$peer_port\n" if $options->debug;
				$0 = "trnd[$peer_address]";
						
				$trn->client($client);
				$trn->peer_addr($peer_address);
				$trn->log($trn_log);
				
				while (my $buff = $client->getline) {
					my ($key, $val) = split '=', $buff;
					$key ||= $buff;
					$key =~ s/(^\s+)|(\s+$)//;
				
					close ($client) and last if $key eq 'quit';
					$trn->run if $key eq '.' and $trn->param('action') and $trn->auth_ok; 
								
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
