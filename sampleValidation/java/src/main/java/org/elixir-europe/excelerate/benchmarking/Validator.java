package org.elixir_europe.excelerate.benchmarking;

import java.io.File;

import java.net.URI;

import java.util.Map;
import java.util.HashMap;

import org.everit.json.schema.Schema;
import org.everit.json.schema.loader.SchemaLoader;
import org.json.JSONObject;
import org.json.JSONTokener;

/**
 * Hello world!
 *
 */
public class Validator
{
	protected Map<URI,ValidatedJSONSchema> schemaHash;
	
	public Validator(File schema) {
	}
	
	public static void main( String[] args )
	{
		if(args.length > 0) {
			File schemaPath = new File(args[0]);
			Validator v = new Validator(schemaPath);
			
			
		} else {
			System.err.println("Usage: jsonValidate {JSON schema} {JSON file}*");
		}
	}
}
