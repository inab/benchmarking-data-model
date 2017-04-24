# EXCELERATE WP2 Benchmarking Data Model repository

This repository contains all the developments around the benchmarking data model which is being developed by ELIXIR-EXCELERATE WP2.

* Folder [early-drafts](early-drafts) contains the initial ideas around what it is needed to be stored in order to model benchmarking events and metrics.

* Folder [json-schemas](json-schemas) contains the the JSON Schemas, based on JSON Schema Draft 04 standard, being developed to validate the different objects used by future WP2 benchmarking services and databases. These schemas contain extensions to declare the primary, unique and foerign keys of the documents, when all the documents are validated as a set, or are stored in a database.

	* Primary key is declared on the top of each schema as an array with the key `primary_key`. A primary key can be composed by more than one property.
	* Foreign keys are declared with keys `foreign_keys` (which is an object). They map the property to the JSON Schema referenced by the `schema_id` property, which is either a relative or absolute URI. When it is relative, it is resolved against the `id` value of the schema where the foerign key is declared. The `property` attribute must contain one of the declared properties in a `primary_key` declaration.
