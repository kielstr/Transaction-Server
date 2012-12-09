package Transaction::Sig;

use Moose;
use Modern::Perl;
use Data::Dumper;
use POSIX qw(:signal_h :sys_wait_h);

has 'children' => (is => 'rw', isa => 'Hashref');
has 'pidname' => (is => 'rw', isa => 'Str');
has 'trn_log' => (is => 'rw', isa => 'Object');

sub BUILD {
	my $self = shift;
	my $children = $self->children_pids;
	my $pidname = $self->pidname;
	my $trn_log = $self->trn_log;

	$SIG{CHLD} = sub { 
		while ((my $child = waitpid(-1,WNOHANG)) > 0) {
			if (my $start = grep { $child eq $_} (keys %{$children->{nowait}}, keys %{$children->{wait}}) ) {
				my $runtime = time() - $start;
				#printf "Child $child ran %dm%ss\n", $runtime / 60, $runtime % 60;
				delete $children->{$child};
			} 
		}
	};

	$SIG{HUP} = sub {
		my $sigset = POSIX::SigSet->new(SIGHUP);
		sigprocmask(SIG_UNBLOCK, $sigset);
	
		kill 15, keys %{$children->{nowait}};

		$trn_log->log('notice', "waiting for spawned proccess to finish") 
			unless waitpid(-1,WNOHANG) == -1;

		sleep until (my $kid = waitpid(-1,WNOHANG)) == -1;
		
		$trn_log->log('notice', 'Restarting trnd');
		$self->SUPER::DESTROY;
                # BUG: exec needs to capture the cmdline args
		exec ($pidname) or die "Couldn't restart: $!\n";
	};

	$SIG{__DIE__} = $SIG{TERM} = $SIG{INT} = sub {
		my $sig = shift;
		kill 15, keys %{$children->{nowait}};
		
		sleep until (my $kid = waitpid(-1,WNOHANG)) == -1;
		$trn_log->log('notice', 'Stopping trnd');
		exit;
	};

}

1;
