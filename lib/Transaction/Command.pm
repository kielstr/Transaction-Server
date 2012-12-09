package Transaction::Command;

use Carp; 
use Moose;
use Modern::Perl;
use Method::Signatures;

my $data = \%{Transaction::_data};

method param ($key, $val?) {
	$data->{COMMANDS}{params}{$key} = $val if $val;
	carp "Invalid key passed to Transaction::WebUI::param $key\n"
		unless exists $data->{COMMANDS}{params}{$key};
	return $data->{COMMANDS}{params}{$key};
}

method execute {
	given ($self->param('action')) {
		when (/restart/) {
			kill 1, $$;
		}
	}
}

1;
