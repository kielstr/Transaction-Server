package Transaction::Pid;

use Moose;
use Modern::Perl;
use Method::Signatures;
use IO::File;
use Carp;
use Data::Dumper;

method running {
	my $data = \%{Transaction::_data};
	my $runfile = $data->{CONFIG}{PIDFILE_DIR}. "/trn.pid";
	
	if (-e $runfile) {
		my $fh = IO::File->new($runfile, 'r');
		croak "Can not open run file $runfile $!" unless defined $fh;
		chomp(my $pid = <$fh>);
		$fh->close;
		return $pid if $pid ne $$ and kill 0, $pid;
	}
	return 0;
}

method create {
	my $data = \%{Transaction::_data};
	my $runfile = $data->{CONFIG}{PIDFILE_DIR}. "/trn.pid";
  	my $fh = IO::File->new($runfile, 'w');
	croak "Failed to create run file $runfile $!" unless defined $fh;
	print $fh "$$";
	$fh->close;	
}

method cleanup {
	my $data = \%{Transaction::_data};
	my $runfile = $data->{CONFIG}{PIDFILE_DIR}. "/trn.pid";
	if (-r $runfile) {
		my $fh = IO::File->new($runfile, 'r');
		croak "Failed to open run file $runfile $!" unless defined $fh;
		chomp (my $pid = <$fh>);
		if ($pid eq $$) {
			unlink $runfile or die "Can not unlink run file $runfile $!";
		}
		undef $fh;
	}
}

sub DESTORY {
	my $self = shift;
	self->cleanup;
}

1;
