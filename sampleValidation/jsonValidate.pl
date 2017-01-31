#!/usr/bin/perl

use warnings 'all';
use strict;

use JSON::MaybeXS;
use JSON::Validator;

if(scalar(@ARGV) > 0) {
	my $jsonSchemaFile = shift(@ARGV);
	
	my $p = JSON->new->convert_blessed;
	my $v;
	
	if(open(my $S,'<:encoding(UTF-8)',$jsonSchemaFile)) {
		print "* Loading schema $jsonSchemaFile\n";
		local $/;
		my $jsonSchemaText = <$S>;
		close($S);
		
		my $jsonSchema = $p->decode($jsonSchemaText);
		
		$v = JSON::Validator->new($jsonSchema);
	} else {
		print STDERR "FATAL ERROR: Unable to open schema file $jsonSchemaFile. Reason: $!\n";
		exit 1;
	}
	
	foreach my $jsonFile (@ARGV) {
		if(open(my $J,'<:encoding(UTF-8)',$jsonFile)) {
			print "* Validating $jsonFile\n";
			local $/;
			my $jsonText = <$J>;
			close($J);
			
			my $json = $p->decode($jsonText);
			
			my @valErrors = $v->validate($json);
			if(scalar(@valErrors) > 0) {
				print "\t- ERRORS:\n".join("\n",map { "\t\tPath: ".$_->{'path'}.' . Message: '.$_->{'message'}} @valErrors)."\n";
			} else {
				print "\t- Validated!\n";
			}
			print "\n";
		} else {
			print STDERR "\t- ERROR: Unable to open file $jsonFile. Reason: $!\n";
		}
	}
} else {
	print STDERR "Usage: $0 {json_schema_file} {json_file}*\n";
	exit 1;
}