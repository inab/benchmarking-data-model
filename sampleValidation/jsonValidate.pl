#!/usr/bin/perl

use warnings 'all';
use strict;

use File::Spec;
use JSON::MaybeXS;
use JSON::Validator 0.95;

sub loadJSONSchemas($\%@) {
	my($v,$p_schemaHash,@jsonSchemaFiles) = @_;
	my $p = JSON->new->convert_blessed;
	
	foreach my $jsonSchemaFile (@jsonSchemaFiles) {
		if(-d $jsonSchemaFile) {
			# It's a possible JSON Schema directory, not a JSON Schema file
			if(opendir(my $JSD,$jsonSchemaFile)) {
				while(my $relJsonSchemaFile = readdir($JSD)) {
					# Skipping hidden files / directories
					next  if(substr($relJsonSchemaFile,0,1) eq '.');
					
					my $newJsonSchemaFile = File::Spec->catfile($jsonSchemaFile,$relJsonSchemaFile);
					push(@jsonSchemaFiles, $newJsonSchemaFile)  if(-d $newJsonSchemaFile || $relJsonSchemaFile =~ /\.json/);
				}
				closedir($JSD);
			} else {
				print STDERR "FATAL ERROR: Unable to open JSON schema directory $jsonSchemaFile. Reason: $!\n";
			}
		} else {
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
							# Curating the primary key
							if(exists($jsonSchema->{'primary_key'})) {
								if(ref($jsonSchema->{'primary_key'}) eq 'ARRAY') {
									foreach my $key (@{$jsonSchema->{'primary_key'}}) {
										if(ref(\$key) ne 'SCALAR') {
											print STDERR "\tWARNING: primary key in $jsonSchemaFile is not composed by strings. Ignoring it\n";
											delete($jsonSchema->{'primary_key'});
										}
									}
								} else {
									delete($jsonSchema->{'primary_key'});
								}
							}
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
}

sub materializeJPath($$) {
	my($json,$jPath) = @_;
	
	my @objectives = ( $json );
	my @jSteps = ($jPath eq '.') ? ( undef ) : split(/\./,$jPath);
	foreach my $jStep (@jSteps) {
		my @newObjectives = ();
		my $isArray;
		my $arrayIndex;
		if($jStep =~ /^([^\[]+)\[(0|[1-9][0-9]+)?\]$/) {
			$isArray = 1;
			$arrayIndex = $2 + 0  if(defined($2));
			$jStep = $1;
		}
		foreach my $objective ( @objectives ) {
			my $value;
			if(defined($jStep)) {
				if(ref($objective) eq 'HASH') {
					$value = $objective->{$jStep};
				} else {
					# Failing
					return undef;
				}
			} else {
				$value = $objective;
			}
			
			if(ref($value) eq 'ARRAY') {
				if(defined($arrayIndex)) {
					push(@newObjectives,$value->[$arrayIndex]);
				} else {
					push(@newObjectives,@{$value});
				}
			} else {
				push(@newObjectives,$value);
			}
		}
		
		@objectives = @newObjectives;
	}
	
	# Flattening it (we return a reference to a list of atomic values)
	foreach my $objective (@objectives) {
		if(ref($objective)) {
			$objective = JSON->new->convert_blessed->encode($objective);
		}
	}
	
	return \@objectives;
}

# It fetches the values from a JSON, based on the given paths to the members of the key
sub getKeyValues($\@) {
	my($json,$p_members) = @_;
	
	return map { materializeJPath($json,$_); } @{$p_members};
}

# It generates pk strings from a set of values
sub genKeyStrings(@) {
	my @pkStrings = ();
	
	my $numPKcols = scalar(@_);
	if($numPKcols > 0) {
		@pkStrings = @{$_[0]};
		shift(@_);
		
		foreach my $curPKvalues (@_) {
			my @newPKstrings = ();
			
			foreach my $curPKvalue (@{$curPKvalues}) {
				push(@newPKstrings,map { $_ . "\0" . $curPKvalue } @newPKstrings);
			}
			
			@pkStrings = @newPKstrings;
		}
	}
	
	return @pkStrings;
}

sub jsonValidate($\%@) {
	my($v,$p_schemaHash,@jsonFiles) = @_;
	my $p = JSON->new->convert_blessed;
	
	# A two level hash, in order to check primary key restrictions
	my %PKvals = ();
	
	# A two level hash, in order to check foreign key restrictions
	my %FKvals = ();
	
	foreach my $jsonFile (@jsonFiles) {
		if(-d $jsonFile) {
			# It's a possible JSON directory, not a JSON file
			if(opendir(my $JSD,$jsonFile)) {
				while(my $relJsonFile = readdir($JSD)) {
					# Skipping hidden files / directories
					next  if(substr($relJsonFile,0,1) eq '.');
					
					my $newJsonFile = File::Spec->catfile($jsonFile,$relJsonFile);
					push(@jsonFiles, $newJsonFile)  if(-d $newJsonFile || $relJsonFile =~ /\.json/);
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
						# Does the schema contain a PK declaration?
						my $isValid = 1;
						if(exists($jsonSchema->{'primary_key'})) {
							my $p_PK;
							if(exists($PKvals{$jsonSchema->{'primary_key'}})) {
								$p_PK = $PKvals{$jsonSchema->{'primary_key'}};
							} else {
								$PKvals{$jsonSchema->{'primary_key'}} = $p_PK = {};
							}
							
							my @pkValues = getKeyValues($json, @{$jsonSchema->{'primary_key'}});
							my @pkStrings = genKeyStrings(@pkValues);
							foreach my $pkString (@pkStrings) {
								if(exists($p_PK->{$pkString})) {
									print STDERR "\t- PK ERROR: Duplicate PK in $jsonFile and ".$p_PK->{$pkString}."\n";
									$isValid = undef;
								} else {
									$p_PK->{$pkString} = $jsonFile;
								}
							}
						}
						
						print "\t- Validated!\n"  if($isValid);
					}
				} else {
					print "\t- Skipping schema validation (schema with URI ".$json->{'_schema'}." not found)\n";
				}
			} else {
				print "\t- Skipping schema validation (no one declared for $jsonFile)\n";
			}
			print "\n";
		} else {
			print STDERR "\t- ERROR: Unable to open file $jsonFile. Reason: $!\n";
		}
	}
	
	# TODO, Once all the data is read, apply FK checks
}

if(scalar(@ARGV) > 0) {
	my $jsonSchemaDir = shift(@ARGV);
	
	my $jsonSchema;
	
	my $v = JSON::Validator->new();
	my %schemaHash = ();
	loadJSONSchemas($v,%schemaHash,$jsonSchemaDir);
	
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
