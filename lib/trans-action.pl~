use Data::Dumper;

sub echotest {
	my $trn = shift;
	for my $key ($trn->param()) {
		trans_data($trn->client, "$key", $trn->param($key));
		#$trn->data($key, $trn->param($key));
	}
        trans_send($trn->client);
	#$trn->send;
}

1;
