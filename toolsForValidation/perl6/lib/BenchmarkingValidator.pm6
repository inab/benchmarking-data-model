use v6;
use JSON::Fast;
use OpenAPI::Schema::Validate;
use URI;

package BenchmarkingValidator {
	our %draft04Schema;

	sub loadMetaSchema(Str $meta-schema = 'draft-04-schema') {
		if %draft04Schema.elems == 0 {
			my $msH = %?RESOURCES{$meta-schema}.open(:r , enc => 'utf-8');
			
			say "* Loading meta schema $meta-schema";
				
			%draft04Schema = from-json($msH.slurp-rest());
			
			$msH.close();
		}
		
		return %draft04Schema;
	}

	sub findFKs(%jsonSchema, URI $jsonSchemaURI , Str $pprefix = "") {
		my $prefix = $pprefix;
		my @FKs = Empty;
		
		# First, this level's foreign keys
		my Bool $isArray = False;
		
		if %jsonSchema{'items'}:exists && %jsonSchema{'items'}.isa('Hash') {
			%jsonSchema = %jsonSchema{'items'};
			$isArray = True;
			
			if $prefix ne '' {
				$prefix ~= '[]';
			}
		}
		
		if %jsonSchema{'foreign_keys'}:exists && %jsonSchema{'foreign_keys'}.isa('Array') {
			for @(%jsonSchema{'foreign_keys'}) -> %fk_def {
				# Only valid declarations are taken into account
					
				if ( %fk_def{'schema_id'}:exists ) && ( %fk_def{'members'}:exists ) {
					my URI $ref_schema_id .= new(%fk_def{'schema_id'});
					my @members = %fk_def{'members'};
					
					if @members.isa('Array') {
						# Translating to absolute URI (in case it is relative)
						# Convert relative to absolute urls
						my $abs_ref_schema_id;
						if $ref_schema_id.scheme.defined && $ref_schema_id.scheme ne '' {
							$abs_ref_schema_id = $ref_schema_id;
						} else {
							# Trying to do it properly by hand, as URI does not allow the operations
							$abs_ref_schema_id = $jsonSchemaURI.Str;
							my $lastSlash = $abs_ref_schema_id.rindex('/');
							if $lastSlash.defined {
								$abs_ref_schema_id = $abs_ref_schema_id.substr(0,$lastSlash+1) ~ $ref_schema_id.Str;
							} else {
								$abs_ref_schema_id ~= $ref_schema_id.Str;
							}
						}
						
						# Translating the paths
						my @components = @members.map({ ($_ ne '' && $_ ne '.') ?? ($prefix ~ '.' ~ $_) !! $prefix });
						
						@FKs.push(($abs_ref_schema_id.Str,@components));
					}
				}
			}
		}
		
		# Then, the foreign keys inside sublevels
		if ( %jsonSchema{'properties'}:exists ) && %jsonSchema{'properties'}.isa('Hash') {
			if $prefix ne '' {
				$prefix ~= '.';
			}
			my %p = %jsonSchema{'properties'};
			for %p.kv -> $k , %subSchema {
				@FKs.append(findFKs(%subSchema,$jsonSchemaURI,$prefix ~ $k));
			}
		}
		
		return @FKs;
	}

	sub loadJSONSchemas(%schemaHash!, *@jsonSchemaFiles) {
		# Schema validation stats
		my Int $numDirOK = 0;
		my Int $numDirFail = 0;
		my Int $numFileOK = 0;
		my Int $numFileIgnore = 0;
		my Int $numFileFail = 0;
		
		say "PASS 0.a: JSON schema loading and validation";
		
		# A schema should have been deserialized into a hash at the top level.
		# It will have been if you use this with OpenAPI::Model.
		my $schemaV = OpenAPI::Schema::Validate.new(
			schema => loadMetaSchema()
		);
		
		for @jsonSchemaFiles -> IO $jsonSchemaFile {
			if $jsonSchemaFile.d {
				# It's a possible JSON Schema directory, not a JSON Schema file
				try {
					for $jsonSchemaFile.dir() -> $relJsonSchemaFile {
						if substr($relJsonSchemaFile.basename,0,1) eq '.' {
							next;
						}
						
						
						my $newJsonSchemaFile = $relJsonSchemaFile;
						if $newJsonSchemaFile.d || $relJsonSchemaFile.basename.index('.json').defined {
							@jsonSchemaFiles.push: $newJsonSchemaFile;
						}
					}
					$numDirOK++;
					
					CATCH {
						when X::IO {
							$*ERR.say: "FATAL ERROR: Unable to open JSON schema directory $jsonSchemaFile. Reason: $_.payload()\n";
							$numDirFail++;
						}
					}
				}
			} else {
				try {
					my $sHandle = $jsonSchemaFile.open(:r, enc => 'utf-8');
					
					say "* Loading schema $jsonSchemaFile";
						
					my %jsonSchema = from-json($sHandle.slurp-rest());
					
					$sHandle.close();
					
					try {
						$schemaV.validate(%jsonSchema);
						
						# Getting the JSON Pointer object instance of the augmented schema
						# my $jsonSchemaP = $v->schema($jsonSchema)->schema;
						# This step is done, so we fetch a complete schema
						# $jsonSchema = $jsonSchemaP->data;
						if %jsonSchema{'id'}:exists {
							my $jsonSchemaURI = %jsonSchema{'id'};
							if %schemaHash{$jsonSchemaURI}:exists  {
								$*ERR.say: "\tERROR: validated, but schema in $jsonSchemaFile and schema in %schemaHash{$jsonSchemaURI}[1] have the same id";
								$numFileFail++;
							} else {
								say "\t- Validated $jsonSchemaURI";
								
								# Curating the primary key
								my $p_PK = Nil;
								if %jsonSchema{'primary_key'}:exists {
									$p_PK = %jsonSchema{'primary_key'};
									unless $p_PK.isa('Array') {
										$p_PK = Nil;
									}
								}
								
								# Gather foreign keys
								my @FKs = findFKs(%jsonSchema,URI.new($jsonSchemaURI));
								
								#print(FKs,file=sys.stderr)
								
								%schemaHash{$jsonSchemaURI} = (%jsonSchema,$jsonSchemaFile,$p_PK,@FKs);
								$numFileOK++;
							}
						} else {
							$*ERR.say: "\tIGNORE: validated, but schema in $jsonSchemaFile has no id attribute";
							$numFileIgnore++;
						}
						
						CATCH {
							when X::OpenAPI::Schema::Validate::Failed {
								$*ERR.say: "\t- ERRORS:\n\t\tPath: $_.path() . Message: $_.reason()\n";
								$numFileFail++;
							}
						}
					}

					CATCH {
						when X::IO {
							$*ERR.say: "FATAL ERROR: Unable to open schema file $jsonSchemaFile . Reason: $_.payload()\n";
							$numFileFail++;
						}
					}
				}
			}
		}
		
		say "\nSCHEMA VALIDATION STATS: loaded $numFileOK schemas from $numDirOK directories, ignored $numFileIgnore schemas, failed $numFileFail schemas and $numDirFail directories";
		
		say "\nPASS 0.b: JSON schema set consistency checks";
		
		# Now, we check whether the declared foreign keys are pointing to loaded JSON schemas
		my Int $numSchemaConsistent = 0;
		my Int $numSchemaInconsistent = 0;
		for %schemaHash.kv -> $jsonSchemaURI, @schema {
			my IO::Path $jsonSchemaFile = @schema[1];
			my $p_FKs = @schema[3];
			say "* Checking $jsonSchemaFile";
			
			my Bool $isValid = True;
			for @$p_FKs -> @p_FK_decl {
				my $fkPkSchemaId = @p_FK_decl[0];
				my $p_FK_def = @p_FK_decl[1];
				
				unless %schemaHash{$fkPkSchemaId}:exists {
					$*ERR.say: "\t- FK ERROR: No schema with $fkPkSchemaId id, required by $jsonSchemaFile ($jsonSchemaURI)";
					
					$isValid = False;
				}
			}
			
			if $isValid {
				say "\t- Consistent!";
				$numSchemaConsistent++;
			} else {
				$numSchemaInconsistent++;
			}
		}
		
		say "\nSCHEMA CONSISTENCY STATS: $numSchemaConsistent schemas right, $numSchemaInconsistent with inconsistencies"
	}

	sub MAIN(Str $jsonSchemaDir!,*@jsonFiles) is export {
		my %schemaHash = ();
		loadJSONSchemas(%schemaHash,$jsonSchemaDir.IO);
		
		if @jsonFiles.elems > 0 {
			if %schemaHash.elems == 0 {
				$*ERR.say: "FATAL ERROR: No schema was successfuly loaded. Exiting...\n";
				exit(1);
			}
			
			#jsonValidate(%schemaHash,@jsonFiles);
		}
	}
}
