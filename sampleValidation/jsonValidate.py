#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import sys
import json
import jsonschema

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