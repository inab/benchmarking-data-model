# ELIXIR-EXCELERATE Benchmarking JSON Schemas

These are the main benchmarking concepts modelled so far using [JSON Hyper-Schema Draft-04](http://json-schema.org/latest/json-schema-hypermedia.html). All of them have `_id`, `_type` and `_version`.

Sample JSON files can be validated against these schemas using scripts located into [sampleValidation](../sampleValidation) directory or [JSON Schema Validator](http://www.jsonschemavalidator.net/):

* [Community](community.json): The description of a benchmarking community, like CASP, CAFA, Quest for Orthologs, etc...

* [Contact](contact.json): A reference contact of a community, tool or metrics 

* [Reference](reference.json): A bibliographic reference, used to document a community, a contact, a tool, a dataset, a benchmarking event or metrics.

* [Tool](tool.json): A tool which can be benchmarked in one or more communities.

* [Metrics](metrics.json): Defined metrics which can be applied over a dataset.

* [Dataset](dataset.json): Either an input or an output dataset, which can be a reference one or the result of a test event.

* [BenchmarkingEvent](benchmarkingEvent.json): A benchmarking event is defined as a challenge, either attended or unattended.

* [TestEvent](testEvent.json): The event where a tool is involved in a challenge, taking as input a dataset, and generating as result a dataset. The generated dataset can hold the values of several metrics related to the challenge, used to assess the quality of the result.

* [idSolv] (idSolv.json): Namespaces for simple ns:id resolver.

