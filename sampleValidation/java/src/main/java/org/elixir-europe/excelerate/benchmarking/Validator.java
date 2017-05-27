package org.elixir_europe.excelerate.benchmarking;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.Reader;

import java.net.URI;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

import org.everit.json.schema.Schema;
import org.everit.json.schema.ValidationException;
import org.everit.json.schema.loader.SchemaLoader;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

/**
 * Hello world!
 *
 */
public class Validator
{
	protected Map<URI,ValidatedJSONSchema> schemaHash;
	
	public Validator() {
		schemaHash = new HashMap<URI,ValidatedJSONSchema>();
	}
	
	public ValidatedJSONSchema addSchema(File jsonSchemaFile)
		throws IOException, ValidationException, SchemaNoIdException, SchemaRepeatedIdException
	{
		try(
			InputStream jsonStream = new BufferedInputStream(new FileInputStream(jsonSchemaFile),1024*1024);
			Reader jsonReader = new InputStreamReader(jsonStream,"UTF-8");
		) {
			JSONTokener jt = new JSONTokener(jsonReader);
			JSONObject jsonSchema = new JSONObject(jt);
			String jsonSchemaSource = jsonSchemaFile.getPath();
			return addSchema(jsonSchema,jsonSchemaSource);
		}
	}
	
	public ValidatedJSONSchema addSchema(JSONObject jsonSchema,String jsonSchemaSource)
		throws ValidationException, SchemaNoIdException, SchemaRepeatedIdException
	{
		ValidatedJSONSchema bSchemaDoc = new ValidatedJSONSchema(jsonSchema,this,jsonSchemaSource);
		
		// If we are here, then there is no error
		schemaHash.put(bSchemaDoc.getId(),bSchemaDoc);
		
		return bSchemaDoc;
	}
	
	public boolean containsSchema(URI jsonSchemaId) {
		return schemaHash.containsKey(jsonSchemaId);
	}
	
	public boolean isEmpty() {
		return schemaHash.isEmpty();
	}
	
	public ValidatedJSONSchema getSchema(URI jsonSchemaId) {
		return schemaHash.get(jsonSchemaId);
	}
	
	public Collection<ValidatedJSONSchema> getSchemas() {
		return schemaHash.values();
	}
}
