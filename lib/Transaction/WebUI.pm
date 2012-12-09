package Transaction::WebUI;

use Carp;
use FindBin qw($Bin);
use Dancer;
use HTML::Template;
use Moose;
use Modern::Perl;
use Method::Signatures;
use Transaction::Client;

use Data::Dumper;

set port => 8080;
set content_type => 'text/html';
set startup_info => 0;

method run ($pipe) {
	$self->{pipe} = $pipe;

        my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);

	get '/' => sub {
		return $tmpl->output;
	};
	
	get '/restart' => sub {
		$self->_command_data('action', 'restart');
		$self->_command_send;
		return "Restarting the server";
	};

	dance;
}

method _command_data ($key, $val?) {
	my $fh = $self->{pipe};
	print $fh join '=', $key, $val;
	print $fh "\n";
	return 1;
}

method _command_send {
	my $fh = $self->{pipe};
	print $fh ".\n";
	return 1;
}

1;
