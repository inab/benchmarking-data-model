#!/usr/bin/perl

use warnings 'all';
use strict;

use File::Spec;
use JSON::MaybeXS;
use JSON::Validator 0.95;

sub loadSchemaDir($$\%);

sub loadSchemaDir($$\%) {
	my($jsonSchemaDir,$v,$p_schemaHash) = @_;
	
	my $p = JSON->new->convert_blessed;
	if(opendir(my $JSD,$jsonSchemaDir)) {
		print "Processing directory $jsonSchemaDir\n";
		while(my $relJsonSchemaFile = readdir($JSD)) {
			# Skipping hidden files / directories
			next  if(substr($relJsonSchemaFile,0,1) eq '.');
			
			my $jsonSchemaFile = File::Spec->catfile($jsonSchemaDir,$relJsonSchemaFile);
			if(-d $jsonSchemaFile) {
				loadSchemaDir($jsonSchemaFile,$v,%{$p_schemaHash});
			} elsif($relJsonSchemaFile =~ /\.json$/) {
				if(open(my $S,'<:encoding(UTF-8)',$jsonSchemaFile)) {
					print "* Loading schema $jsonSchemaFile\n";
					local $/;
					my $jsonSchemaText = <$S>;
					close($S);
					
					my $jsonSchema = $p->decode($jsonSchemaText);
					my @valErrors = $v->schema(JSON::Validator::SPECIFICATION_URL)->validate($jsonSchema);
					if(scalar(@valErrors) > 0) {
						print "\t- ERRORS:\n".join("\n",map { "\t\tPath: ".$_->{'path'}.' . Message: '.$_->{'message'}} @valErrors)."\n";
					} else {
						if(exists($jsonSchema->{'id'})) {
							if(exists($p_schemaHash->{$jsonSchema->{'id'}})) {
								print STDERR "\tERROR: validated, but schema in $jsonSchemaFile and schema in ".$p_schemaHash->{$jsonSchema->{'id'}}[1]." have the same id\n";
							} else {
								print "\t- Validated ".$jsonSchema->{'id'}."\n";
								$p_schemaHash->{$jsonSchema->{'id'}} = [$jsonSchema,$jsonSchemaFile];
							}
						} else {
							print STDERR "\tERROR: validated, but schema in $jsonSchemaFile has no id attribute\n";
						}
					}
				} else {
					print STDERR "FATAL ERROR: Unable to open schema file $jsonSchemaFile. Reason: $!\n";
				}
			}
		}
		closedir($JSD);
	} else {
		print STDERR "FATAL ERROR: Unable to open JSON schema directory $jsonSchemaDir. Reason: $!\n";
		exit 1;
	}
}

sub jsonValidate($\%@) {
	my($v,$p_schemaHash,@jsonFiles) = @_;
	my $p = JSON->new->convert_blessed;
	
	foreach my $jsonFile (@jsonFiles) {
		if(-d $jsonFile) {
			# It's a possible JSON directory, not a JSON file
			if(opendir(my $JSD,$jsonFile)) {
				while(my $relJsonFile = readdir($JSD)) {
					# Skipping hidden files / directories
					next  if(substr($relJsonFile,0,1) eq '.');
					
					my $newJsonFile = File::Spec->catfile($jsonFile,$relJsonFile);
					push(@jsonFiles, $newJsonFile)  if(-d $newJsonFile || $relJsonFile =~ /\.json$/);
				}
				closedir($JSD);
			} else {
				print STDERR "FATAL ERROR: Unable to open JSON directory $jsonFile. Reason: $!\n";
			}
		} elsif(open(my $J,'<:encoding(UTF-8)',$jsonFile)) {
			print "* Validating $jsonFile\n";
			local $/;
			my $jsonText = <$J>;
			close($J);
			
			my $json = $p->decode($jsonText);
			
			if(exists($json->{'_schema'})) {
				if(exists($p_schemaHash->{$json->{'_schema'}})) {
					print "\t- Using ".$json->{'_schema'}." schema\n";
					
					my $jsonSchema = $p_schemaHash->{$json->{'_schema'}}[0];
					my @valErrors = $v->validate($json,$jsonSchema);
					if(scalar(@valErrors) > 0) {
						print "\t- ERRORS:\n".join("\n",map { "\t\tPath: ".$_->{'path'}.' . Message: '.$_->{'message'}} @valErrors)."\n";
					} else {
						print "\t- Validated!\n";
					}
				} else {
					print "\t- Skipping schema validation (schema with URI ".$json->{'_schema'}." not found)\n";
					print "\t- No schema declared for $jsonFile\n";
				}
			} else {
				print "\t- Skipping schema validation (no one declared for $jsonFile)\n";
			}
			print "\n";
		} else {
			print STDERR "\t- ERROR: Unable to open file $jsonFile. Reason: $!\n";
		}
	}
}

if(scalar(@ARGV) > 0) {
	my $jsonSchemaDir = shift(@ARGV);
	
	my $jsonSchema;
	
	my $v = JSON::Validator->new();
	my %schemaHash = ();
	loadSchemaDir($jsonSchemaDir,$v,%schemaHash);
	
	if(scalar(@ARGV) > 0) {
		if(scalar(keys(%schemaHash))==0) {
			print STDERR "FATAL ERROR: No schema was successfuly loaded. Exiting...\n";
			exit 1;
		}
		
		jsonValidate($v,%schemaHash,@ARGV);
	}
} else {
	print STDERR "Usage: $0 {json_schema_directory} {json_file}*\n";
	exit 1;
}
