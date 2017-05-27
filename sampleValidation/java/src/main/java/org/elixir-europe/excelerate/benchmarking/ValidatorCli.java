package org.elixir_europe.excelerate.benchmarking;

import java.io.BufferedInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.Reader;

import java.net.URI;

import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
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
public class ValidatorCli
{
	protected Validator p_schemaHash;
	
	public ValidatorCli(List<File> jsonSchemaFiles) {
		p_schemaHash = new Validator();
		
		// Schema validation stats
		int numDirOK = 0;
		int numDirFail = 0;
		int numFileOK = 0;
		int numFileIgnore = 0;
		int numFileFail = 0;
		
		System.out.println("PASS 0.a: JSON schema loading and validation");
		System.out.flush();
		
		// It is done so, in order to avoid the ConcurrentModificationException
		for(int iJsonSchemaFile = 0; iJsonSchemaFile < jsonSchemaFiles.size(); iJsonSchemaFile++) {
			File jsonSchemaFile = jsonSchemaFiles.get(iJsonSchemaFile);
			if(jsonSchemaFile.isDirectory()) {
				// It's a possible JSON Schema directory, not a JSON Schema file
				Path jsonSchemaDir = jsonSchemaFile.toPath();
				try(DirectoryStream<Path> jsonSchemaDirStream = Files.newDirectoryStream(jsonSchemaDir)) {
					for(Path newJsonSchemaPath: jsonSchemaDirStream) {
						File newJsonSchemaFile = newJsonSchemaPath.toFile();
						if(newJsonSchemaFile.getName().charAt(0)!='.') {
							if(newJsonSchemaFile.isDirectory() || newJsonSchemaFile.getName().contains(".json")) {
								jsonSchemaFiles.add(newJsonSchemaFile);
							}
						}
					}
					numDirOK++;
				} catch(IOException ioe) {
					System.err.printf("FATAL ERROR: Unable to open JSON schema directory %s. Reason: %s\n",jsonSchemaFile.getPath(),ioe.getMessage());
					System.err.flush();
					numDirFail++;
				}
			} else {
				try {
					System.out.printf("* Loading schema %s\n",jsonSchemaFile.getPath());
					System.out.flush();
					ValidatedJSONSchema bSchemaDoc = p_schemaHash.addSchema(jsonSchemaFile);
					System.out.printf("\t- Validated %s\n",bSchemaDoc.getId().toString());
					System.out.flush();
					for(String warning: bSchemaDoc.getWarnings()) {
						System.err.println("\tWARNING: "+warning);
						System.err.flush();
					}
					numFileOK++;
				} catch(ValidationException ve) {
					System.err.println("\t- ERRORS:");
					ve.getCausingExceptions().stream().forEach(se -> System.err.printf("\t\tPath: %s . Message: %s\n",se.getPointerToViolation(),se.getMessage()));
					System.err.flush();
					numFileFail++;
				} catch(SchemaNoIdException snie) {
					System.err.println("\tIGNORE: "+snie.getMessage());
					System.err.flush();
					numFileIgnore++;
				} catch(SchemaRepeatedIdException srie) {
					System.err.println("\tERROR: "+srie.getMessage());
					System.err.flush();
					numFileFail++;
				} catch(IOException ioe) {
					System.err.printf("FATAL ERROR: Unable to open schema file %s. Reason: %s\n",jsonSchemaFile.getPath(),ioe.getMessage());
					System.err.flush();
					numFileFail++;
				}
			}
		}

		System.out.printf("\nSCHEMA VALIDATION STATS: loaded %d schemas from %d directories, ignored %d schemas, failed %d schemas and %d directories\n",numFileOK,numDirOK,numFileIgnore,numFileFail,numDirFail);
		
		System.out.println("\nPASS 0.b: JSON schema set consistency checks");
		
		// Now, we check whether the declared foreign keys are pointing to loaded JSON schemas
		int numSchemaConsistent = 0;
		int numSchemaInconsistent = 0;
		for(ValidatedJSONSchema p_schema: p_schemaHash.getSchemas()) {
			System.out.printf("* Checking %s\n",p_schema.getJsonSchemaSource());
			
			try {
				p_schema.consistencyChecks(p_schemaHash);
				System.out.println("\t- Consistent!");
				numSchemaConsistent ++;
			} catch(SchemaInconsistentException sie) {
				sie.getInconsistencies().forEach(incon -> System.err.println("\t FK ERROR: "+incon));
				numSchemaInconsistent++;
			}
		}
		
		System.out.printf("\nSCHEMA CONSISTENCY STATS: %d schemas right, %d with inconsistencies\n",numSchemaConsistent,numSchemaInconsistent);
	}
	
	public boolean isEmpty() {
		return p_schemaHash.isEmpty();
	}
	
	public void jsonValidate(List<File> jsonFiles) {
		// TODO
	}
	
	public static void main( String[] args )
	{
		if(args.length > 0) {
			List<File> jsonFiles = Arrays.stream(args).map(jsonPath -> new File(jsonPath)).collect(Collectors.toCollection(ArrayList::new));
			File jsonSchemaPath = jsonFiles.remove(0);
			List<File> jsonSchemaFiles = new ArrayList<File>();
			jsonSchemaFiles.add(jsonSchemaPath);
			ValidatorCli vcli = new ValidatorCli(jsonSchemaFiles);
			
			if(!jsonFiles.isEmpty()) {
				if(vcli.isEmpty()) {
					System.err.println("FATAL ERROR: No schema was successfuly loaded. Exiting...");
					System.exit(1);
				}
				
				vcli.jsonValidate(jsonFiles);
			}
		} else {
			System.err.println("Usage: jsonValidate {JSON schema} {JSON file}*");
			System.exit(1);
		}
	}
}
