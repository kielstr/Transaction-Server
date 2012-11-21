package Transaction::Sig;

use strict;
use warnings;

use POSIX qw(:signal_h :sys_wait_h);

sub new {
	my $self = shift;
	$self =	bless {}, $self;
	$self->init(@_);
	return $self;

}

sub init {
	my ($children, $script_name, $trn_log) = @_;
	$SIG{CHLD} = sub { 
		while ((my $child = waitpid(-1,WNOHANG)) > 0) {
			if (my $start = $children->{$child}) {
				my $runtime = time() - $start;
				printf "Child $child ran %dm%ss\n", $runtime / 60, $runtime % 60;
				delete $children->{$child};
			} 
		}
	};

	$SIG{HUP} = sub {
		my $sigset = POSIX::SigSet->new(SIGHUP);
		sigprocmask(SIG_UNBLOCK, $sigset);
	
		$trn_log->log('notice', "waiting for spawned proccess to finish") 
			unless waitpid(-1,WNOHANG) == -1;

		sleep until (my $kid = waitpid(-1,WNOHANG)) == -1;
	
		$trn_log->log('notice', 'Restarting trnd');
		exec($script_name) or die "Couldn't restart: $!\n";
	};

	$SIG{TERM} = $SIG{INT} = sub {
		$trn_log->log('notice', "waiting for spawned proccess to finish") unless waitpid(-1,WNOHANG) == -1;
		sleep until (my $kid = waitpid(-1,WNOHANG)) == -1;

		$trn_log->log('notice', 'Stopping trnd');
		exit;
	};

}

1;
