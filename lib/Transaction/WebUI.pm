package Transaction::WebUI;

use strict;
use warnings;
use Dancer;
use HTML::Template;
use FindBin qw($Bin);
use Transaction::Client;
use Data::Dumper;

set port => 8080;
set content_type => 'text/plain';
set startup_info => 0;

sub run {
	my ($self, $pipe) = @_;
	$pipe->reader;
	
	my $tmpl = HTML::Template->new(
		die_on_bad_params => 0,
		filename => "$Bin/WebUI-Templates/main.tmpl"
	);

	get '/' => sub {
		return $tmpl->output;
	};
	
	get '/restart' => sub {
		#my $trn = Transaction::Client->new(PORT=>5001, HOST=>'localhost');
		#$trn->send('nobody', 'opennow', 'restart');
		#$trn->quit;
		
		print $pipe "Woop";

		#return '<pre>'. Dumper($trn) . "</PRE>";
		return "restarting the server";
	};

	dance;
}

1;
