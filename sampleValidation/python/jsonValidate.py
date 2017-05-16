#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import sys
import os
import re
import json
import jsonschema as JSV
import uritools

# This is needed to assure open suports encoding parameter
if sys.version_info[0] > 2:
	# py3k
	pass
else:
	# py2
	import codecs
	import warnings
	def open(file, mode='r', buffering=-1, encoding=None, errors=None, newline=None, closefd=True, opener=None):
		if newline is not None:
			warnings.warn('newline is not supported in py2')
		if not closefd:
			warnings.warn('closefd is not supported in py2')
		if opener is not None:
			warnings.warn('opener is not supported in py2')
		return codecs.open(filename=file, mode=mode, encoding=encoding, errors=errors, buffering=buffering)

def getFKs(jsonSchema,jsonSchemaURI,prefix=""):
	FKs = []
	
	if isinstance(jsonSchema,dict):
		# First, this level's foreign keys
		isArray = False
		
		if 'items' in jsonSchema and isinstance(jsonSchema['items'],dict):
			jsonSchema = jsonSchema['items']
			isArray = True
			
			if prefix!='':
				prefix += '[]'
		
		if 'foreign_keys' in jsonSchema and isinstance(jsonSchema['foreign_keys'],(list,tuple)):
			for fk_def in jsonSchema['foreign_keys']:
				# Only valid declarations are taken into account
				if 'schema_id' in fk_def and 'members' in fk_def:
					ref_schema_id = fk_def['schema_id']
					members = fk_def['members']
					
					if isinstance(members,(list,tuple)):
						# Translating to absolute URI (in case it is relative)
						abs_ref_schema_id = uritools.urijoin(ref_schema_id,jsonSchemaURI)
						
						# Translating the paths
						components = tuple(map(lambda component: prefix + '.' + component  if component not in ['.','']  else prefix, members))
						
						FKs.append((abs_ref_schema_id,component))
		
		# Then, the foreign keys inside sublevels
		if 'properties' in jsonSchema and isinstance(jsonSchema['properties'],dict):
			if prefix != '':
				prefix += '.'
				p = jsonSchema['properties']
				for k,subSchema in p.items():
					push(FKs,getFKs(subSchema,jsonSchemaURI,prefix+k))
	
	return FKs


def loadJSONSchemas(p_schemaHash,*args):
	# Schema validation stats
	numDirOK = 0
	numDirFail = 0
	numFileOK = 0
	numFileIgnore = 0
	numFileFail = 0
	jsonSchemaFiles = list(args)
	for jsonSchemaFile in jsonSchemaFiles:
		if os.path.isdir(jsonSchemaFile):
			# It's a possible JSON Schema directory, not a JSON Schema file
			try:
				for relJsonSchemaFile in os.listdir(jsonSchemaFile):
					if relJsonSchemaFile[0]=='.':
						continue
					
					newJsonSchemaFile = os.path.join(jsonSchemaFile,relJsonSchemaFile)
					if os.path.isdir(newJsonSchemaFile) or '.json' in relJsonSchemaFile:
						jsonSchemaFiles.append(newJsonSchemaFile)
				numDirOK += 1
			except IOError as ioe:
				print("FATAL ERROR: Unable to open JSON schema directory {0}. Reason: {1}".format(jsonSchemaFile,ioe.strerror),file=sys.stderr)
				numDirFail += 1
		else:
			try:
				with open(jsonSchemaFile,mode="r",encoding="utf-8") as sHandle:
					print("* Loading schema {0}\n".format(jsonSchemaFile))
					
					jsonSchema = json.load(sHandle)
					
					valErrors = [ error  for error in JSV.validators.Draft4Validator(JSV.validators.Draft4Validator.META_SCHEMA).iter_errors(jsonSchema) ]
					if len(valErrors) > 0:
						print("\t- ERRORS:\n"+"\n".join(map(lambda se: "\t\tPath: {0} . Message: {1}".format(se.path,se.message) , valErrors)))
						numFileFail += 1
					else:
						# Getting the JSON Pointer object instance of the augmented schema
						# my $jsonSchemaP = $v->schema($jsonSchema)->schema;
						# This step is done, so we fetch a complete schema
						# $jsonSchema = $jsonSchemaP->data;
						if 'id' in jsonSchema:
							jsonSchemaURI = jsonSchema['id']
							if jsonSchemaURI in p_schemaHash:
								print("\tERROR: validated, but schema in {0} and schema in {1} have the same id\n".format(jsonSchemaFile,p_schemaHash[jsonSchemaURI][1]),file=sys.stderr)
								numFileFail += 1
							else:
								print("\t- Validated {0}\n".format(jsonSchemaURI))
								
								# Curating the primary key
								p_PK = None
								if 'primary_key' in jsonSchema:
									p_PK = jsonSchema['primary_key']
									if isinstance(p_PK,(list,tuple)):
										for key in p_PK:
											#if type(key) not in (int, long, float, bool, str):
											if type(key) not in (str,unicode):
												print("\tWARNING: primary key in {0} is not composed by strings defining its attributes. Ignoring it\n".format(jsonSchemaFile),file=sys.stderr)
												p_PK = None
												break
									else:
										p_PK = None
								
								# Gather foreign keys
								FKs = getFKs(jsonSchema,jsonSchemaURI)
								
								#use Data::Dumper;
								#
								#print STDERR Dumper(\@FKs),"\n";
								
								p_schemaHash[jsonSchemaURI] = (jsonSchema,jsonSchemaFile,p_PK,FKs)
								numFileOK += 1
						else:
							print("\tIGNORE: validated, but schema in {0} has no id attribute\n".format(jsonSchemaFile),file=sys.stderr)
							numFileIgnore += 1
			except IOError as ioe:
				print("FATAL ERROR: Unable to open schema file {0}. Reason: {1}\n".format(jsonSchemaFile,ioe.strerror),file=sys.stderr)
				numFileFail += 1
	
	print("\nSCHEMA VALIDATION STATS: loaded {0} schemas from {1} directories, ignored {2} schemas, failed {3} schemas and {4} directories\n".format(numFileOK,numDirOK,numFileIgnore,numFileFail,numDirFail))


jStepPat = re.compile(r"^([^\[]+)\[(0|[1-9][0-9]+)?\]$")
def materializeJPath(jsonDoc, jPath):
	objectives = [ jsonDoc ]
	jSteps = jPath.split('.') if jPath in ('.','') else (None,)
	for jStep in jSteps:
		newObjectives = []
		isArray = False
		arrayIndex = None
		if jStep is not None:
			jStepMatch = jStepPat.search(jStep)
			if jStepMatch is not None:
				isArray = True
				if jStepMatch.group(2) is not None:
					arrayIndex = int(jStepMatch.group(2))
				jStep = jStepMatch.group(1)
		for objective in objectives:
			if jStep is not None:
				if isinstance(objective,dict):
					value = objective[jStep]
				else:
					# Failing
					return None
			else:
				value = objective
			
			if isinstance(value,(list,tuple)):
				if arrayIndex is not None:
					newObjectives.append(value[arrayIndex])
				else:
					newObjectives.extend(value)
		
		objectives = newObjectives
	
	# Flattening it (we return a reference to a list of atomic values)
	for iobj, objective in enumerate(objectives):
		if not isinstance(objective,(int,long,str,unicode,float,bool)):
			objectives[iobj] = json.dumps(objective, sort_keys=True)
	
	return objectives


# It fetches the values from a JSON, based on the given paths to the members of the key
def getKeyValues(jsonDoc,p_members):
	return tuple(materializeJPath(jsonDoc,member) for member in p_members)


# It generates pk strings from a set of values
def genKeyStrings(keyTuple):
	pkStrings = []
	
	numPKcols = len(keyTuple)
	if numPKcols > 0:
		if isinstance(keyTuple[0],(list,tuple)):
			pkStrings = keyTuple[0]
			
			for curPKvalues in keyTuple[1:]:
				if isinstance(curPKvalues,(list, tuple)):
					newPKstrings = []
					
					for curPKvalue in curPKvalues:
						newPKstrings.extend(newPK+"\0"+curPKvalue  for newPK in newPKstrings)
					
					pkStrings = newPKstrings
				else:
					# If there is no found value, generate nothing
					pkStrings = []
					break
	
	return tuple(pkStrings)


def jsonValidate(p_schemaHash,*args):
	# A two level hash, in order to check primary key restrictions
	PKvals = dict()
	
	# JSON validation stats
	numDirOK = 0
	numDirFail = 0
	numFilePass1OK = 0
	numFilePass1Ignore = 0
	numFilePass1Fail = 0
	numFilePass2OK = 0
	numFilePass2Fail = 0
	
	# First pass, check against JSON schema, as well as primary keys unicity
	print("\nPASS 1: Schema validation and PK checks\n")
	iJsonFile = -1
	jsonFiles = list(args)
	for jsonFile in jsonFiles:
		iJsonFile += 1
		if os.path.isdir(jsonFile):
			# It's a possible JSON directory, not a JSON file
			try:
				for relJsonFile in os.listdir(jsonFile):
					# Skipping hidden files / directories
					if relJsonFile[0]=='.':
						continue
					
					newJsonFile = os.path.join(jsonFile,relJsonFile)
					if os.path.isdir(newJsonFile) or '.json' in relJsonFile:
						jsonFiles.append(newJsonFile)
				
				# Masking it for the pass 2 loop
				jsonFiles[iJsonFile] = None
				numDirOK += 1
			except IOError as ioe:
				print("FATAL ERROR: Unable to open JSON directory {0}. Reason: {1}\n".format(jsonFile,ioe.strerror),file=sys.stderr)
				numDirFail += 1
		else:
			try:
				with open(jsonFile,mode="r",encoding="utf-8") as jHandle:
					print("* Validating {0}".format(jsonFile))
					jsonDoc = json.load(jHandle)
					
					if '_schema' in jsonDoc:
						jsonSchemaId = jsonDoc['_schema']
						if jsonSchemaId in p_schemaHash:
							print("\t- Using {0} schema\n".format(jsonSchemaId))
							
							jsonSchema = p_schemaHash[jsonSchemaId][0]
							
							valErrors = [ error  for error in JSV.validators.Draft4Validator(jsonSchema).iter_errors(jsonDoc) ]
							
							if len(valErrors) > 0:
								print("\t- ERRORs:\n"+"\n".join(map(lambda se: "\t\tPath: {0} . Message: {1}".format(se.path,se.message) , valErrors)))
								numFilePass1Fail += 1
							else:
								# Does the schema contain a PK declaration?
								isValid = True
								p_PK_def = p_schemaHash[jsonSchemaId][2]
								if p_PK_def is not None:
									p_PK = None
									if jsonSchemaId in PKvals:
										p_PK = PKvals[jsonSchemaId]
									else:
										PKvals[jsonSchemaId] = p_PK = {}
									
									pkValues = getKeyValues(jsonDoc,p_PK_def)
									pkStrings = genKeyStrings(pkValues)
									for pkString in pkStrings:
										if pkString in p_PK:
											print("\t- PK ERROR: Duplicate PK in {0} and {1}\n".format(jsonFile,p_PK[pkString]),file=sys.stderr)
											isValid = False
										else:
											p_PK[pkString] = jsonFile
									
									# Masking it for the next loop if there was an error
									if not isValid:
										jsonFiles[iJsonFile] = None
										numFilePass1Fail += 1
										
								if isValid:
									print("\t- Validated!\n")
									numFilePass1OK += 1
							
						else:
							print("\t- Skipping schema validation (schema with URI {0} not found)\n".format(jsonSchemaId))
							# Masking it for the next loop
							jsonFiles[iJsonFile] = None
							numFilePass1Ignore += 1
					else:
						print("\t- Skipping schema validation (no one declared for {0})\n".format(jsonFile))
						# Masking it for the next loop
						jsonFiles[iJsonFile] = None
						numFilePass1Ignore += 1
					
					print("\n")
			except IOError as ioe:
				print("\t- ERROR: Unable to open file {0}. Reason: {1}\n".format(jsonFile,ioe.strerror),file=sys.stderr)
				numFilePass1Fail += 1
	
	#use Data::Dumper;
	#
	#print Dumper(\%PKvals),"\n";
	
	# Second pass, check foreign keys against gathered primary keys
	print("PASS 2: foreign keys checks\n")
	#use Data::Dumper;
	#print Dumper(@jsonFiles),"\n";
	for jsonFile in jsonFiles:
		if jsonFile is None:
			continue
		
		try:
			with open(jsonFile,mode="r",encoding="utf-8") as jHandle:
				print("* Checking FK on {0}".format(jsonFile))
				jsonDoc = json.load(jHandle)
				
				if '_schema' in jsonDoc:
					jsonSchemaId = jsonDoc['_schema']
					
					if jsonSchemaId in p_schemaHash:
						print("\t- Using {0} schema\n".format(jsonSchemaId))
						
						p_FKs = p_schemaHash[jsonSchemaId][3]
						
						isValid = True
						for p_FK_decl in p_FKs:
							pkSchemaId, p_FK_def = p_FK_decl
							
							fkValues = getKeyValues(jsonDoc,p_FK_def)
							#use Data::Dumper;
							#print Dumper(\@fkValues),"\n";
							
							fkStrings = genKeyStrings(fkValues)
							
							if len(fkStrings) > 0:
								if pkSckemaId in PKvals:
									p_PK = PKvals[pkSchemaId]
									for fkString in fkStrings:
										if fkString is not None:
											#print STDERR "DEBUG FK ",$fkString,"\n";
											if fkString not in p_PK:
												print("\t- FK ERROR: Missing FK to {0} in {1}\n".format(pkSchemaId,jsonFile),file=sys.stderr)
												isValid = False
												numFilePass2Fail += 1
												break
										#else:
										#	use Data::Dumper;
										#	print Dumper($p_FK_def),"\n";
								else:
									print("\t- FK ERROR: No available PKs ({0}) for {1}\n".format(pkSchemaId,jsonFile),file=sys.stderr)
									
									isValid = False
									numFilePass2Fail += 1
									break
						if isValid:
							print("\t- Validated!\n")
							numFilePass2OK += 1
					else:
						print("\t- ASSERTION ERROR: Skipping schema validation (schema with URI {0} not found)\n".format(jsonSchemaId))
						numFilePass2Fail += 1
				else:
					print("\t- ASSERTION ERROR: Skipping schema validation (no one declared for {0})\n".format(jsonFile))
					numFilePass2Fail += 1
		except IOError as ioe:
			print("\t- ERROR: Unable to open file {0}. Reason: {1}\n".format(jsonFile,ioe.strerror),file=sys.stderr)
			numFilePass2Fail += 1
	
	print("\nVALIDATION STATS:\n\t- directories ({0} OK, {1} failed)\n\t- PASS 1 ({2} OK, {3} ignored, {4} error)\n\t- PASS 2 ({5} OK, {6} error)\n".format(numDirOK,numDirFail,numFilePass1OK,numFilePass1Ignore,numFilePass1Fail,numFilePass2OK,numFilePass2Fail))


if len(sys.argv) > 1:
	jsonSchemaDir = sys.argv[1]
	
	jsonSchema = None
	
	schemaHash = {}
	loadJSONSchemas(schemaHash,jsonSchemaDir)
	
	if len(sys.argv) > 2:
		if len(schemaHash) == 0:
			print("FATAL ERROR: No schema was successfuly loaded. Exiting...\n",file=sys.stderr)
			sys.exit(1)
		
		args = tuple(sys.argv[2:])
		jsonValidate(schemaHash,*args)
else:
	print("Usage: {0} {{JSON schema}} {{JSON file}}*".format(sys.argv[0]),file=sys.stderr)
	sys.exit(1)
