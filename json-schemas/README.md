# ELIXIR-EXCELERATE Benchmarking JSON Schemas

These are the latest benchmarking concepts modelled so far using [JSON Schema Draft-07](https://json-schema.org/latest/json-schema-core.html), available in [1.0.x folder](1.0.x). All of them have `_id` and `_schema` attributes.

Sample JSON files can be validated against these schemas using scripts located into [extended JSON Schema validators](//github.com/inab/extended-json-validators) repository or [JSON Schema Validator](http://www.jsonschemavalidator.net/). There is even a script to generate a chart describing these schemas:

![Benchmarking JSON Schema 1.0.x](schemaChart-1.0.x.dot.png "Benchmarking JSON Schema 1.0.x")

* [Community](1.0.x/community.json): The description of a benchmarking community, like CASP, CAFA, Quest for Orthologs, etc...

* [Contact](1.0.x/contact.json): A reference contact of a community, tool or metrics.

* [Reference](1.0.x/reference.json): A bibliographic reference, used to document a community, a contact, a tool, a dataset, a benchmarking event or metrics.

* [Tool](1.0.x/tool.json): A tool which can be used in the lifecycle of one or more benchmarking communities.

* [Metrics](1.0.x/metrics.json): Defined metrics which can be computed from a dataset.

* [Dataset](1.0.x/dataset.json): Any one of the datasets involved in the benchmarking events lifecycle. So, they can be interrelated (for data provenance) and cross-referenced from the other concepts.

* [BenchmarkingEvent](1.0.x/benchmarkingEvent.json): A benchmarking event is defined as a set of challenges coordinated by a community, either attended or unattended.

* [Challenge](1.0.x/challenge.json): A challenge is composed by a set of one or more test actions, related to the participants involved in the challenge.

* [TestAction](1.0.x/testAction.json): The involvement of a tool in a challenge, taking as input the datasets defined for the challenge, and generating the result datasets in the format agreed by the community. The generated datasets are later related to metrics datasets, which are the metrics agreed by the community for the challenge, used later to assess the quality of the result.

* [idSolv](1.0.x/idsolv.json): This side concept is used to model [CURIE](https://en.wikipedia.org/wiki/CURIE)'s which are not yet registered in [identifiers.org](https://identifiers.org).
