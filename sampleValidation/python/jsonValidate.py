#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import sys
import os
import re
import json
import jsonschema
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
		
		if 'foreign_keys' in jsonSchema and isinstance(jsonSchema['foreign_keys'],list):
			for fk_def in jsonSchema['foreign_keys']:
				# Only valid declarations are taken into account
				if 'schema_id' in fk_def and 'members' in fk_def:
					ref_schema_id = fk_def['schema_id']
					members = fk_def['members']
					
					if isinstance(members,list):
						# Translating to absolute URI (in case it is relative)
						abs_ref_schema_id = uritools.urijoin(ref_schema_id,jsonSchemaURI)
						
						# Translating the paths
						components = list(map(lambda component: prefix + '.' + component  if component not in ['.','']  else prefix, members))
						
						FKs.append((abs_ref_schema_id,component))
		
		# Then, the foreign keys inside sublevels
		if 'properties' in jsonSchema and isinstance(jsonSchema['properties'],dict):
			if prefix != '':
				prefix += '.'
				p = jsonSchema['properties']
				for k,subSchema in p.items():
					push(FKs,getFKs(subSchema,jsonSchemaURI,prefix+k))
	
	return FKs


def loadJSONSchemas(p_schemaHash,*jsonSchemaFiles):
	# Schema validation stats
	numDirOK = 0
	numDirFail = 0
	numFileOK = 0
	numFileIgnore = 0
	numFileFail = 0
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
			except IOError ioe:
				print("FATAL ERROR: Unable to open JSON schema directory {0}. Reason: {1}".format(jsonSchemaFile,ioe.strerror),file=sys.stderr)
				numDirFail += 1
		else:
			try:
				with open(jsonSchemaFile,mode="r",encoding="utf-8") as sHandle:
					print("* Loading schema {0}\n".format(jsonSchemaFile))
					
					jsonSchema = json.load(sHandle)
					
					try:
						jsonschema.Draft4Validator.check_schema(jsonSchema)
						
						# Getting the JSON Pointer object instance of the augmented schema
						# my $jsonSchemaP = $v->schema($jsonSchema)->schema;
						# This step is done, so we fetch a complete schema
						# $jsonSchema = $jsonSchemaP->data;
						if 'id' in jsonSchema:
							print("\t- Validated {0}\n".format(jsonSchemaURI))
							
							# Curating the primary key
							p_PK = None
							if 'primary_key' in jsonSchema:
								p_PK = jsonSchema['primary_key']
								if isinstance(p_PK,list):
									for key in p_PK:
										#if type(key) not in (int, long, float, bool, str):
										if type(key) not in (str):
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
					except jsonschema.exceptions.SchemaError se:
						print("\t- ERROR:\n"+"\n".join("\t\tPath: {0} . Message: {1}".format(se.path,se.message)))
						numFileFail += 1
			except IOError ioe:
				print("FATAL ERROR: Unable to open schema file {0}. Reason: {1}\n".format(jsonSchemaFile,ioe.strerror),file=sys.stderr)
				numFileFail += 1
	
	print("\nSCHEMA VALIDATION STATS: loaded {0} schemas from {1} directories, ignored {2} schemas, failed {3} schemas and {4} directories\n".format(numFileOK,numDirOK,numFileIgnore,numFileFail,numDirFail))


jStepPat = re.compile(r"^([^\[]+)\[(0|[1-9][0-9]+)?\]$")
def materializeJPath(jsonDoc, jPath):
	objectives = [ jsonDoc ]
	jSteps = jPath.split('.') if jPath in ('.','') else None
	for jStep in jSteps:
		newObjectives = []
		isArray = False
		arrayIndex = None
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
			
			if isinstance(value,list):
				if arrayIndex is not None:
					newObjectives.append(value[arrayIndex])
				else:
					newObjectives.extend(value)
		
		objectives = newObjectives
	
	# Flattening it (we return a reference to a list of atomic values)
	for iobj, objective in enumerate(objectives):
		if not isinstance(objective,(int,long,str,float,bool)):
			objectives[iobj] = json.dumps(objective, sort_keys=True)
	
	return objectives


# It fetches the values from a JSON, based on the given paths to the members of the key
def getKeyValues(jsonDoc,p_members):
	return [materializeJPath(jsonDoc,member) for member in p_members]


# It generates pk strings from a set of values
def genKeyStrings(*args):
	pkStrings = []
	
	numPKcols = len(args)
	if numPKcols > 0:
		if isinstance(args[0],list):
			pkStrings = args[0]
			
			for curPKvalues in args[1:]:
				if isinstance(curPKvalues,list):
					newPKstrings = []
					
					for curPKvalue in curPKvalues:
						newPKstrings.extend(newPK+"\0"+curPKvalue  for newPK in newPKstrings)
					
					pkStrings = newPKstrings
				else:
					# If there is no found value, generate nothing
					pkStrings = []
					break
	
	return pkStrings


def jsonValidate(p_schemaHash,*jsonFiles):
	# A two level hash, in order to check primary key restrictions
	PKvals = dict()
	
	# First pass, check against JSON schema, as well as primary keys unicity
	print("\nPASS 1: Schema validation and PK checks\n")
	for jsonFile in jsonFiles:
		if os.path.isdir(jsonFile):
			# It's a possible JSON directory, not a JSON file
			try:
				for relJsonFile in os.listdir(jsonFile):
					
			except IOException ioe:
				print("FATAL ERROR: Unable to open JSON directory {0}. Reason: {1}\n".format(jsonFile,ioe.strerror),file=sys.stderr)


if len(sys.argv) > 1:
	jsonSchemaFile = sys.argv[1]
	with open(jsonSchemaFile,mode="r",encoding="utf-8") as sHandle:
		schema = json.load(sHandle)
		jsonschema.Draft4Validator.check_schema(schema)
		
		if len(sys.argv) > 2:
			for jsonFile in sys.argv[2:]:
				with open(jsonFile,mode="r",encoding="utf-8") as jHandle:
					jContent = json.load(jHandle)
					jsonschema.validate(jContent,schema)
else:
	print("Usage: {0} {{JSON schema}} {{JSON file}}*".format(sys.argv[0]),file=sys.stderr)
