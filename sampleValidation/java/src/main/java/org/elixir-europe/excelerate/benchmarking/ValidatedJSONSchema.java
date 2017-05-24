package org.elixir_europe.excelerate.benchmarking;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.Reader;

import java.net.URI;
import java.net.URISyntaxException;

import java.util.ArrayList;
import java.util.Collection;

import org.everit.json.schema.Schema;
import org.everit.json.schema.loader.SchemaLoader;
import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

public class ValidatedJSONSchema {
	protected JSONObject jsonSchema;
	protected URI jsonSchemaURI;
	protected Schema jsonSchemaVal;
	protected File jsonSchemaFile;
	
	protected Collection<String> p_PK;
	protected Collection<ForeignKey> FKs;
	
	protected static final Schema Draft4Schema = SchemaLoader.load(
		new JSONObject(
			new JSONTokener(
				ValidatedJSONSchema.class.getResourceAsStream("/org/everit/json/schema/json-schema-draft-04.json")
			)
		)
	);
	
	protected class ForeignKey {
		protected final URI refSchemaId;
		protected final Collection<String> components;
		
		public ForeignKey(URI abs_ref_schema_id,Collection<String> components) {
			refSchemaId = abs_ref_schema_id;
			this.components = components;
		}
		
		public final URI getSchemaURI() {
			return refSchemaId;
		}
		
		public final Collection<String> getComponents() {
			return components;
		}
	}
	
	protected Collection<ForeignKey> _getFKs() {
		return _getFKs(jsonSchema);
	}
	
	protected Collection<ForeignKey> _getFKs(Object schema) {
		return _getFKs(schema,"");
	}
	
	protected Collection<ForeignKey> _getFKs(Object schema,String prefix) {
		Collection<ForeignKey> FKs = new ArrayList<ForeignKey>();
		
		if(schema instanceof JSONObject) {
			JSONObject jsonSchema = (JSONObject)schema;
			
			// First, this level's foreign keys
			boolean isArray = false;
			
			if(jsonSchema.has("items") && jsonSchema.get("items") instanceof JSONObject) {
				jsonSchema = (JSONObject) jsonSchema.get("items");
				isArray = true;
				
				if(prefix.length() > 0) {
					prefix += "[]";
				}
			}
			
			if(jsonSchema.has("foreign_keys") && jsonSchema.get("foreign_keys") instanceof JSONArray) {
				for(Object fk_def_obj: (JSONArray)jsonSchema.get("foreign_keys")) {
					// Only valid declarations are taken into account
					if(fk_def_obj instanceof JSONObject) {
						JSONObject fk_def = (JSONObject) fk_def_obj;
						if(fk_def.has("schema_id") && fk_def.has("members")) {
							String ref_schema_id = fk_def.getString("schema_id");
							Object members = fk_def.get("members");
							
							if(members instanceof JSONArray) {
								// Translating to absolute URI (in case it is relative)
								URI abs_ref_schema_id = jsonSchemaURI.resolve(ref_schema_id);
								
								Collection<String> components = new ArrayList<String>();
								for(Object component: (JSONArray)members) {
									String compStr = component.toString();
									components.add((compStr.length() > 0 && !compStr.equals("."))?prefix+"."+compStr:compStr);
								}
								
								FKs.add(new ForeignKey(abs_ref_schema_id,components));
							}
						}
					}
				}
			}
			
			// Then, the foreign keys inside sublevels
			if(jsonSchema.has("properties") && jsonSchema.get("properties") instanceof JSONObject) {
				if(prefix.length()>0) {
					prefix += ".";
				}
				
				JSONObject p = (JSONObject)jsonSchema.get("properties");
				for(String k: p.keySet()) {
					Object subschema = p.get(k);
					FKs.addAll(_getFKs(subschema,prefix+k));
				}
			}
		}
		
		return FKs;
	}
	
	public ValidatedJSONSchema(File jsonSchemaFile)
		throws IOException
	{
		this.jsonSchemaFile = jsonSchemaFile;
		
		try(
			InputStream jsonStream = new BufferedInputStream(new FileInputStream(jsonSchemaFile),1024*1024);
			Reader jsonReader = new InputStreamReader(jsonStream,"UTF-8");
		) {
			JSONTokener jt = new JSONTokener(jsonReader);
			jsonSchema = new JSONObject(jt);
			Draft4Schema.validate(jsonSchema);
			
			// # Getting the JSON Pointer object instance of the augmented schema
			// # my $jsonSchemaP = $v->schema($jsonSchema)->schema;
			// # This step is done, so we fetch a complete schema
			// # $jsonSchema = $jsonSchemaP->data;
			if(jsonSchema.has("id")) {
				try{
					jsonSchemaURI = new URI(jsonSchema.getString("id"));
					p_PK = null;
					if(jsonSchema.has("primary_key")) {
						Object p_PK_obj = jsonSchema.get("primary_key");
						if(p_PK_obj instanceof JSONArray) {
							Collection<String> p_PK_list = new ArrayList<String>();
							for(Object key: (JSONArray)p_PK_obj) {
								if(key instanceof String) {
									p_PK_list.add((String)key);
								} else {
									// TODO: register this warning
									// # print("\tWARNING: primary key in {0} is not composed by strings defining its attributes. Ignoring it".format(jsonSchemaFile),file=sys.stderr)
									p_PK_list = null;
									break;
								}
							}
							
							if(p_PK_list != null) {
								p_PK = p_PK_list;
							}
						}
					}
					
					FKs = _getFKs();
				} catch(URISyntaxException use) {
					// IgnoreIt(R)
				}
			} else {
				// Throw an ignore exception
			}
			
			// And at last
			jsonSchemaVal = SchemaLoader.load(jsonSchema);
		}
	}
	
	public final URI getId() {
		return jsonSchemaURI;
	}
	
	public void validate(JSONObject jsonDoc) {
		jsonSchemaVal.validate(jsonDoc);
	}
}
