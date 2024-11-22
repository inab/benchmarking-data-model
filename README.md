# OpenEBench Benchmarking Data Model repository
_(born from ELIXIR EXCELERATE WP2)_

This repository contains all the developments around the [OpenEBench scientific benchmarking](https://openebench.bsc.es/benchmarking/) data model.

[![Benchmarking JSON Schema 2.0.x](openebench-bdm-2.0.x.dot.png "Benchmarking JSON Schema 2.0.x")](https://inab.github.io/responsive.graphviz.svg/openebench-bdm-2.0.x.html)

## JSON Schemas
Folder [json-schemas](json-schemas) contains the Scientific Benchmarking Data Model JSON Schemas, being developed to validate the different concepts modelled as JSON objects used by OpenEBench scientific benchmarking services and databases. They were written using JSON Schema Draft 04 standard for [version 0.4](json-schemas/0.4.x), JSON Schema Draft 07 standard for [version 1.0](json-schemas/1.0.x) and JSON Schema Draft 2019-09 standard for [version 2.0](json-schemas/2.0.x). These schemas use extensions to the standards which were modelled based on relational databases concepts, in order to declare the primary and foreign keys of the documents, used when all the documents are validated as a set, or are stored in a database.

  * Primary key is declared on the top of each schema as an array with the key `primary_key`. A primary key can be composed by more than one property.
  * Foreign keys are declared with keys `foreign_keys` (which is an object) at any schema level. They map the declared properties to the JSON Schema key referenced by the `schema_id` property, which is either a relative or absolute URI. When it is relative, it is resolved against the `id` value of the schema where the foerign key is declared. The `members` attribute is an array, and it must contain the list of attributes (or the path to them, separated by dots) which map to the ones in `primary_key` declaration in the referenced schema. Attribute order does matter. When the `foreign_keys` declaration points to a primary key with a single attribute, it can be included at atomic value level, and use the special attribute name `.`.
  
Extended documentation of these JSON Schema extensions is available at [README-extensions.md](//github.com/inab/python-extended-json-schema-validator/blob/main/README-extensions.md)

## Prototype and sample data
Folder [prototype-data](prototype-data) contains several JSON data sets for the different versions of the data model, which validate against the benchmarking JSON schemas.

* Visit [Tools for validation](toolsForValidation.md) in order to learn about several reference programs, which validate the JSON data sets against the benchmarking JSON schemas.

* Folder [early-drafts](early-drafts) contains the initial ideas around what it is needed to be stored in order to model benchmarking events and metrics.
