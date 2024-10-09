# ELIXIR-EXCELERATE Benchmarking JSON Schemas

These are the latest benchmarking concepts modelled so far using [JSON Schema 2019-09](https://json-schema.org/draft/2019-09/json-schema-core.html), available in [2.0.x folder](2.0.x). All of them have `_id`, `_schema` and other common attributes. The prefix of the `$id` of these schemas has been changed to https://w3id.org/openebench/scientific-schemas/2.0/ , in order to provide permanent / stable links to them. For instance, https://w3id.org/openebench/scientific-schemas/2.0/Community is going to be redirected to the raw version of [2.0.x/community.json](2.0.x/community.json).

Sample JSON files can be validated against these schemas using the [extended JSON Schema validator in Python](https://pypi.org/project/extended-json-schema-validator/) repository or [JSON Schema Validator](http://www.jsonschemavalidator.net/). The extended JSON Schema validator is also able to generate a [Graphviz DOT](https://graphviz.org/doc/info/lang.html) graph describing a set of schemas. There is even a semi-interactive viewer which consumes SVGs generated from Graphviz DOT files (click next image for it):

[![Benchmarking JSON Schema 2.0.x](openebench-bdm-2.0.x.dot.png "Benchmarking JSON Schema 2.0.x")](https://inab.github.io/responsive.graphviz.svg/openebench-bdm-2.0.x.html)

These are the main concepts of the OpenEBench Benchmarking Data Model:

* [Community](2.0.x/community.json): The description of a benchmarking community, like CASP, CAFA, Quest for Orthologs, etc...

* [Contact](2.0.x/contact.json): A reference contact of a community, tool or metrics.

* [Reference](2.0.x/reference.json): A bibliographic reference, used to document a community, a contact, a tool, a dataset, a benchmarking event or metrics.

* [Tool](2.0.x/tool.json): A tool which can be used in the lifecycle of one or more benchmarking communities.

* [Metrics](2.0.x/metrics.json): Defined metrics which can be computed from a dataset.

* [Dataset](2.0.x/dataset.json): Any one of the datasets involved in the benchmarking events lifecycle. So, they can be interrelated (for data provenance) and cross-referenced from the other concepts.

* [BenchmarkingEvent](2.0.x/benchmarkingEvent.json): A benchmarking event is defined as a set of challenges coordinated by a community, either attended or unattended.

* [Challenge](2.0.x/challenge.json): A challenge is composed by a set of one or more test actions, related to the participants involved in the challenge.

* [TestAction](2.0.x/testAction.json): The involvement of a tool in a challenge, taking as input the datasets defined for the challenge, and generating the result datasets in the format agreed by the community. The generated datasets are later related to metrics datasets, which are the metrics agreed by the community for the challenge, used later to assess the quality of the result.

* [idSolv](2.0.x/idsolv.json): This side concept is used to model [CURIE](https://en.wikipedia.org/wiki/CURIE)'s which are not yet registered in [identifiers.org](https://identifiers.org).
