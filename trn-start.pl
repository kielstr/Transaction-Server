#!/usr/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use POSIX qw(:signal_h :sys_wait_h);
use Sys::Syslog qw(:DEFAULT setlogsock);
use Getopt::Long;
use DB_File;
use Data::Dumper;

use vars qw(%users %actions);
use Transaction;

#Some config constants
use constant SELF => "$FindBin::Bin/trn-start.pl";
use constant SERVER_PORT => 50001;

use constant PID_NAME => 'Transaction server';
use constant PID_FILE => '/var/run/trn.pid';
use constant STATUS_FILE => '/tmp/trn-status';

use constant TRANSACTION_FILE => 'trn-actions.pl';
use constant ACCESSLIST_FILE => 'trn-access.pl';

use constant SSL_KEY => "$FindBin::Bin/certs/server-key.pem";
use constant SSL_CERT => "$FindBin::Bin/certs/server-cert.pem";
use constant SSL_CA => "$FindBin::Bin/certs/ca";
use constant SSL_CA_FILE => "$FindBin::Bin/certs/my-ca.pem";
use constant SSL_PASSWD => 'testing';

#Check if server is running
BEGIN: { 
	$| = 1;
	if (my $pid = _is_running()) {
		die PID_NAME." running [$pid]"
	}
};

#Hope and pray that we can cleanup 
END: {_clean()};
DISTORY: {_clean()};

my ($server, %kids, %args, @cached_argv);
my $trn = new Transaction; #Transaction obj

_check_options();

#Install handler to catch SIGHUP
$SIG{HUP} = sub {
	my $sigset = POSIX::SigSet->new(SIGHUP);
	sigprocmask(SIG_UNBLOCK, $sigset);
	
	trans_log('notice', "waiting for spawned proccess to finish\n")
		and sleep until (my $kid = waitpid(-1,WNOHANG)) == -1;
	
	trans_log('notice', 'Restarting %s', PID_NAME);
	_clean();
	exec(SELF, @cached_argv) or die "Couldn't restart: $!\n";
};

#Install handler to catch SIGINT and SIGTERM
$SIG{TERM} = $SIG{INT} = sub {
	trans_log('notice', 'Stopping %s', PID_NAME);
	close ($server);
	_clean();
	exit;
};

#Install handler to catch SIGCHLD.
$SIG{CHLD} = sub { 
	my ($child, $start);
	while ((my $kid = waitpid(-1,WNOHANG)) > 0) {
		if ($start = $kids{$kid}) {
			my $runtime = time() - $start;
			#printf "Child $kid ran %dm%ss\n", $runtime / 60, $runtime % 60;
			delete $kids{$kid};
		} 
	}
};

#Block SIGPIPE -- ssl sends a sigpipe for some reason.
$SIG{PIPE} = 'IGNORE';

#Install handler to catch local die and warn calls.
$SIG{'__DIE__'} = sub {
	trans_log('notice', 'Die: %s', $_[0]);
	_clean();
	die @_;
};

$SIG{'__WARN__'} = sub {
	trans_log('notice', 'Die: %s', $_[0]);
};

#Read in the access lists and transactions.
foreach my $file (TRANSACTION_FILE, ACCESSLIST_FILE) {
	unless (my $return = do $file) {
		die "couldn't parse $file: $@" if $@;
		die "couldn't do $file: $!"    unless defined $return;
		die "couldn't run $file"       unless $return;
	}
}

if (exists $args{ssl} and $args{ssl}) {
	#Open SSL TCP port
	use IO::Socket::SSL;
	
	$server = IO::Socket::SSL->new(
		Listen => 10,
		LocalPort => SERVER_PORT,
		Proto     => 'tcp',
		Reuse     => 1,
		SSL_use_cert => 1,
		SSL_key_file => SSL_KEY,
		SSL_cert_file => SSL_CERT,
		SSL_ca_path => SSL_CA,
		SSL_ca_file => SSL_CA_FILE,		
		SSL_verify_mode => 0x01,
		SSL_passwd_cb => sub {return SSL_PASSWD},
	) or die "unable to create socket: ", &IO::Socket::SSL::errstr, "\n";

} else {
	#Open TCP port
	use IO::Socket;
	
	$server = IO::Socket::INET->new (
		LocalPort	=> SERVER_PORT,
		Type		=> SOCK_STREAM,
		Reuse		=> 1,
		Listen		=> 10 
	) or die "Couldn't be a tcp server on port ".SERVER_PORT." : $@\n";
}

#Record process and start accepting
trans_log('notice', 'Started on port %s', SERVER_PORT);
_create_runfile();
_set_state("accepting on port ".SERVER_PORT);
_stats('start_time' => time());

while (1) {
	my $client = $server->accept() || next;
	
	if (!$client) {
		warn "error: ", $server->errstr, "\n";
		next;
	}
		
	my $peer = _peeraddr($client);
	_stats($peer => '++');
	_stats('connection_count' => '++');
	
	#Reject any peers that are not in access list 
	unless (grep /^.*-$peer$/, keys %users) {
		trans_log('err', 'Service to %s rejected on port %d', $peer, SERVER_PORT);
		trans_error($client, 3);
		_stats("peer_rejected" => '++');
		shutdown $client, 2;
		next;
	}
		
	if (my $kidpid = fork()) {
		$kids{$kidpid} = time();
		_stats('spawned_process' => '++');

	} else {
		my $sigset = POSIX::SigSet->new(SIGINT, SIGHUP, SIGTERM);
		my $old_sigset = POSIX::SigSet->new;
		
		#Block any SIG till after this transaction
		unless (defined sigprocmask(SIG_BLOCK, $sigset, $old_sigset)) {
			trans_log('err', "Could not block SIGS");
		}

		$trn->params($client, (exists $args{ssl} and $args{ssl}) ? 1 : 0);
		my $action = $trn->param('ACTION');
		my $user = $trn->param('USER');
		my $passwd = $trn->param('PASSWD');
	
		_stats('transaction_count' => '++');
	
		#Check for an action
		unless ($action) {
			trans_log('info', "Not null transaction requested from %s", $peer);
			trans_error($client, 4);
			_stats('transaction_rejected' => '++');
			shutdown $client, 2;
			exit;
		}

		#Auth peer checking access to transaction, username and passwd
		unless ((my $errcode = _authpeer($action, $peer, $user, $passwd)) == 0) {
			trans_log('err', '%s request from %s rejected on port %d',$action, $peer, SERVER_PORT);
			trans_error($client, $errcode);
			_stats('transaction_rejected' => '++');
			exit;
		}
		
		_set_state("$action request from $peer on port ".SERVER_PORT);
		trans_log('info', '%s request from %s on port %s', $action, $peer, SERVER_PORT);
		_stats($action => '++');
		
		#Eval transaction.
		{	local $SIG{'__DIE__'} = sub {
				trans_log('err', TRANSACTION_FILE.': %s', $_[0]);
			};	
			eval "main_$action(\$client, \$trn)";
			die "parse: $@" if $@;
		}
		
		#Unblock any SIG sent
		unless (defined sigprocmask(SIG_UNBLOCK, $sigset, $old_sigset)) {
			trans_log('err', "Could not block SIGS");
		}
		
		shutdown $client, 2;
		exit;
	}

}

shutdown $server, 2;

#Public subs
sub trans_log {
	my ($priority, $format, @args) = @_;
	
	if (exists $args{d} and $args{d}) {
		printf "DEBUG: $format\n", @args;
	}
	
	if (exists $args{v} and $args{v} eq 'low') {
		return unless $priority eq 'err';
	} elsif (exists $args{v} and $args{v} eq 'medium') {
		return if $priority eq 'info';
	}
	
	
	setlogsock('unix');
    	openlog(PID_NAME ." $$", 'ndelay', 'local1');
	syslog( $priority, $format, @args);
	closelog();
}	
    
sub trans_data {
	my ($socket, @args) = @_;
	return unless defined $args[0] and defined $args[1];
	print $socket "$args[0]=$args[1]\n";
}

sub trans_send {
	my ($socket) = @_;
	print $socket "err=0\n";
}

sub trans_error {
	my ($socket, $errcode) = @_;
	print $socket "err=$errcode\n";
}

#Admin transactions
sub main_status {
	my ($socket, $trn) = @_;
	my %status = _stats();

	my $difference = time() - $status{start_time};
	my $seconds = $difference % 60;
	$difference = ($difference - $seconds) / 60;
	my $minutes = $difference % 60;
	$difference = ($difference - $minutes) / 60;
	my $hours =  $difference % 24;
	$difference = ($difference - $hours)   / 24;
	my $days =  $difference % 7;
	my $weeks = ($difference - $days)    /  7;
	#my $years = ($difference - $weeks)   /  52;
	
	my $uptime = sprintf '%d weeks, %d days, %02d:%02d:%02d', $weeks, $days, $hours, $minutes, $seconds;

	trans_data($socket, 'uptime', $uptime);
	trans_data($socket, $_, $status{$_}) foreach keys %status;

	trans_send($socket);
	return 1;
}

sub main_transaction_list {
	my ($socket, $trn) = @_;
	foreach my $action (keys %actions) {
		trans_data($socket, 'transactions', $action);
	}
	trans_send($socket);
	return 1;
}

sub main_access_list {
	my ($socket, $trn) = @_;
	foreach my $user (keys %users) {
		trans_data($socket, 'accesslist', $user);
	}
	trans_send($socket);
	return 1;
}

sub main_echotest {
	my ($socket, $trn) = @_;
	
	foreach my $key ($trn->param()) {
		my $val = $trn->param($key);
		trans_data($socket, $key, $val);
	}
	trans_send($socket);
	return 1;
}

#Private subs
sub _set_state { $0 = PID_NAME." [@_]" } 

sub _check_options {
	# Some defaults
	%args = (
		d => 0, #debug off
		v => 'high', #log-level high
		ssl => 0, #ssl socket no
	);
	
	@cached_argv = @ARGV;
	GetOptions(
		"verbose=s"	=> \$args{v},     # --verbose
		"debug"		=> \$args{d},       # --Debug
		"ssl"		=> \$args{ssl}
	);
}

sub _peeraddr {
	my $sock = shift;
	my $other_end = getpeername($sock)	
		or die "Couldn't identify other end: $!\n";
    
	my ($port, $iaddr) = unpack_sockaddr_in($other_end);
	return inet_ntoa($iaddr);
} 

sub _authpeer {
	my ($action, $peer, $user, $passwd) = @_;
	
	if (exists $actions{$action}) {
		if (ref $actions{$action} eq 'ARRAY') {
			return 5 unless grep /^$user$/, @{$actions{$action}};
		} else {
			return 5 unless $actions{$action} eq $user;
		}
	} else {
		return 4;
	}

	if (exists $users{"$user-$peer"}) {
		return 2 unless $users{"$user-$peer"} eq $passwd;
	} else {
		return 3;
	}
		
	return 0;	
}

sub _is_running {
	if (-e PID_FILE) {
		open F, PID_FILE or die $!;
		my $pid = <F>;
		close F;
		if (kill 0, $pid) {
			return $pid;
		}
	}
	return 0; 
}

sub _create_runfile {
	open F, ">".PID_FILE or die $!;
	print F $$;
	close F;
}

sub _stats {
	my %args = @_;
	my %status;
	tie %status, "DB_File", STATUS_FILE, O_CREAT|O_RDWR, 0640 or die $!;
	foreach my $key (keys %args) {
		if ($args{$key} eq '++') {
			$status{$key}++
		} else {
			$status{$key} = $args{$key};
		}
	}
	my %ret = %status;
	untie %status;
	return %ret;
}

sub _clean {
	close ($server) if defined $server;
	kill 2, $_ foreach keys %kids;
	unlink STATUS_FILE;
	unlink PID_FILE;
}
