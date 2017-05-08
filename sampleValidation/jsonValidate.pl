#!/usr/bin/perl

use warnings 'all';
use strict;

use FindBin qw();
use File::Spec qw();
use lib File::Spec->catfile($FindBin::Bin,'perllibs','lib','perl5');

use JSON::MaybeXS;
use JSON::Validator 0.95;

use URI;

use IO::Handle;
STDOUT->autoflush;
STDERR->autoflush;

sub getFKs($$;$);

sub getFKs($$;$) {
	my($jsonSchema,$jsonSchemaURI,$prefix) = @_;
	$prefix = ""  unless(defined($prefix));
	
	my @FKs = ();
	
	if(ref($jsonSchema) eq 'HASH') {
		# First, this level's foreign keys
		my $isArray = undef;
		
		if(exists($jsonSchema->{'items'}) && ref($jsonSchema->{'items'}) eq 'HASH') {
			$jsonSchema = $jsonSchema->{'items'};
			$isArray = 1;
			
			$prefix .= '[]'  if($prefix ne '');
		}
		
		if(exists($jsonSchema->{'foreign_keys'}) && ref($jsonSchema->{'foreign_keys'}) eq 'ARRAY') {
			foreach my $fk_def (@{$jsonSchema->{'foreign_keys'}}) {
				# Only valid declarations are taken into account
				if(exists($fk_def->{'schema_id'}) && exists($fk_def->{'members'})) {
					my($ref_schema_id,$members) = @{$fk_def}{'schema_id','members'};
					
					if(ref($members) eq 'ARRAY') {
						# Translating to absolute URI (in case it is relative)
						my $abs_ref_schema_id = URI->new_abs($ref_schema_id,$jsonSchemaURI);
						
						# Translating the paths
						my @components = map {  ($_ ne '.' && $_ ne '') ? $prefix . '.' . $_ : $prefix } @{$members};
						
						push(@FKs,[$abs_ref_schema_id,\@components]);
					}
				}
			}
		}
		
		# Then, the foreign keys inside sublevels
		if(exists($jsonSchema->{'properties'}) && ref($jsonSchema->{'properties'}) eq 'HASH') {
			$prefix .= "."  unless($prefix eq '');
			my $p = $jsonSchema->{'properties'};
			while(my($k,$subSchema) = each(%{$p})) {
				push(@FKs,getFKs($subSchema,$jsonSchemaURI,$prefix.$k));
			}
		}
	}
	
	return @FKs;
}

sub loadJSONSchemas(\%@) {
	my($p_schemaHash,@jsonSchemaFiles) = @_;
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
				my $v = JSON::Validator->new();
				my @valErrors = $v->schema(JSON::Validator::SPECIFICATION_URL)->validate($jsonSchema);
				if(scalar(@valErrors) > 0) {
					print "\t- ERRORS:\n".join("\n",map { "\t\tPath: ".$_->{'path'}.' . Message: '.$_->{'message'}} @valErrors)."\n";
				} else {
					# Getting the JSON Pointer object instance of the augmented schema
					my $jsonSchemaP = $v->schema($jsonSchema)->schema;
					# This step is done, so we fetch a complete schema
					$jsonSchema = $jsonSchemaP->data;
					if(exists($jsonSchema->{'id'})) {
						my $jsonSchemaURI = $jsonSchema->{'id'};
						if(exists($p_schemaHash->{$jsonSchemaURI})) {
							print STDERR "\tERROR: validated, but schema in $jsonSchemaFile and schema in ".$p_schemaHash->{$jsonSchemaURI}[1]." have the same id\n";
						} else {
							print "\t- Validated $jsonSchemaURI\n";
							
							# Curating the primary key
							my $p_PK = undef;
							if(exists($jsonSchema->{'primary_key'})) {
								$p_PK = $jsonSchema->{'primary_key'};
								if(ref($jsonSchema->{'primary_key'}) eq 'ARRAY') {
									foreach my $key (@{$jsonSchema->{'primary_key'}}) {
										if(ref(\$key) ne 'SCALAR') {
											print STDERR "\tWARNING: primary key in $jsonSchemaFile is not composed by strings. Ignoring it\n";
											$p_PK = undef;
											last;
										}
									}
								} else {
									$p_PK = undef;
								}
							}
							
							# Gather foreign keys 
							my @FKs = getFKs($jsonSchema,$jsonSchemaURI);
							
							#use Data::Dumper;
							#
							#print STDERR Dumper(\@FKs),"\n";
							
							$p_schemaHash->{$jsonSchemaURI} = [$jsonSchema,$jsonSchemaFile,$p_PK,\@FKs];
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
	my @jSteps = ($jPath eq '.' || $jPath eq '') ? ( undef ) : split(/\./,$jPath);
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
		if(ref($_[0]) eq 'ARRAY') {
			@pkStrings = @{$_[0]};
			shift(@_);
			
			foreach my $curPKvalues (@_) {
				if(ref($curPKvalues) eq 'ARRAY') {
					my @newPKstrings = ();
					
					foreach my $curPKvalue (@{$curPKvalues}) {
						push(@newPKstrings,map { $_ . "\0" . $curPKvalue } @newPKstrings);
					}
					
					@pkStrings = @newPKstrings;
				} else {
					# If there is no found value, generate nothing
					@pkStrings=();
					last;
				}
			}
		}
	}
	
	return @pkStrings;
}

sub jsonValidate(\%@) {
	my($p_schemaHash,@jsonFiles) = @_;
	my $p = JSON->new->convert_blessed;
	
	# A two level hash, in order to check primary key restrictions
	my %PKvals = ();
	
	# First pass, check against JSON schema, as well as primary keys unicity
	print "PASS 1: Schema validation and PK checks\n";
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
				
				# Masking it for the next loop
				$jsonFile = undef;
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
					my $jsonSchemaId = $json->{'_schema'};
					print "\t- Using $jsonSchemaId schema\n";
					
					my $jsonSchema = $p_schemaHash->{$jsonSchemaId}[0];
					
					my $v = JSON::Validator->new()->schema($jsonSchema);
					my @valErrors = $v->validate($json);
					if(scalar(@valErrors) > 0) {
						print "\t- ERRORS:\n".join("\n",map { "\t\tPath: ".$_->{'path'}.' . Message: '.$_->{'message'}} @valErrors)."\n";
						
						# Masking it for the next loop
						$jsonFile = undef;
					} else {
						# Does the schema contain a PK declaration?
						my $isValid = 1;
						my $p_PK_def = $p_schemaHash->{$jsonSchemaId}[2];
						if(defined($p_PK_def)) {
							my $p_PK;
							if(exists($PKvals{$jsonSchemaId})) {
								$p_PK = $PKvals{$jsonSchemaId};
							} else {
								$PKvals{$jsonSchemaId} = $p_PK = {};
							}
							
							my @pkValues = getKeyValues($json, @{$p_PK_def});
							my @pkStrings = genKeyStrings(@pkValues);
							foreach my $pkString (@pkStrings) {
								if(exists($p_PK->{$pkString})) {
									print STDERR "\t- PK ERROR: Duplicate PK in $jsonFile and ".$p_PK->{$pkString}."\n";
									$isValid = undef;
								} else {
									$p_PK->{$pkString} = $jsonFile;
								}
							}
							
							# Masking it for the next loop if there was an error
							$jsonFile = undef  unless($isValid);
						}
						
						print "\t- Validated!\n"  if($isValid);
					}
				} else {
					print "\t- Skipping schema validation (schema with URI ".$json->{'_schema'}." not found)\n";
					# Masking it for the next loop
					$jsonFile = undef;
				}
			} else {
				print "\t- Skipping schema validation (no one declared for $jsonFile)\n";
				# Masking it for the next loop
				$jsonFile = undef;
			}
			print "\n";
		} else {
			print STDERR "\t- ERROR: Unable to open file $jsonFile. Reason: $!\n";
		}
	}
	
	#use Data::Dumper;
	#
	#print Dumper(\%PKvals),"\n";
	
	# Second pass, check foreign keys against gathered primary keys
	print "PASS 2: foreign keys checks\n";
	#use Data::Dumper;
	#print Dumper(@jsonFiles),"\n";
	foreach my $jsonFile (@jsonFiles) {
		next  unless(defined($jsonFile));
		
		if(open(my $J,'<:encoding(UTF-8)',$jsonFile)) {
			print "* Checking FK on $jsonFile\n";
			local $/;
			my $jsonText = <$J>;
			close($J);
			
			my $json = $p->decode($jsonText);
			
			if(exists($json->{'_schema'})) {
				if(exists($p_schemaHash->{$json->{'_schema'}})) {
					my $jsonSchemaId = $json->{'_schema'};
					print "\t- Using $jsonSchemaId schema\n";
					
					my $p_FKs = $p_schemaHash->{$jsonSchemaId}[3];
					
					my $isValid = 1;
					foreach my $p_FK_decl (@{$p_FKs}) {
						my($pkSchemaId,$p_FK_def) = @{$p_FK_decl};
						
						my @fkValues = getKeyValues($json, @{$p_FK_def});
						#use Data::Dumper;
						#print Dumper(\@fkValues),"\n";
						
						my @fkStrings = genKeyStrings(@fkValues);
						
						if(scalar(@fkStrings) > 0) {
							if(exists($PKvals{$pkSchemaId})) {
								my $p_PK = $PKvals{$pkSchemaId};
								foreach my $fkString (@fkStrings) {
									if(defined($fkString)) {
										unless(exists($p_PK->{$fkString})) {
											print STDERR "\t- FK ERROR: Missing FK to $pkSchemaId in $jsonFile\n";
											$isValid = undef;
											last;
										}
									#} else {
									#	use Data::Dumper;
									#	print Dumper($p_FK_def),"\n";
									}
								}
							} else {
								print STDERR "\t- FK ERROR: No available PKs ($pkSchemaId) in $jsonFile\n";
								
								$isValid = undef;
								last;
							}
						}
					}
					print "\t- Validated!\n"  if($isValid);
				} else {
					print "\t- ASSERTION ERROR: Skipping schema validation (schema with URI ".$json->{'_schema'}." not found)\n";
				}
			} else {
				print STDERR "\t- ASSERTION ERROR: Skipping schema validation (no one declared for $jsonFile)\n";
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
	
	my %schemaHash = ();
	loadJSONSchemas(%schemaHash,$jsonSchemaDir);
	
	if(scalar(@ARGV) > 0) {
		if(scalar(keys(%schemaHash))==0) {
			print STDERR "FATAL ERROR: No schema was successfuly loaded. Exiting...\n";
			exit 1;
		}
		
		jsonValidate(%schemaHash,@ARGV);
	}
} else {
	print STDERR "Usage: $0 {json_schema_directory} {json_file_or_directory}*\n";
	exit 1;
}
