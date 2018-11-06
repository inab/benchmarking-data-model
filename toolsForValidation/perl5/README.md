# EXCELERATE WP2 JSON Schema validation, Perl edition

All the benchmarking JSON schemas should be compliant with JSON Schema Draft04 specification.

So, the proposed validation programs use libraries compliant with that specification.

The installation instructions are available at [INSTALL.md](INSTALL.md).

* [jsonValidate.pl](jsonValidate.pl) Perl program can be run using next command line, to validate using version 0.4 of the schemas:
  ```bash
  source .plenv/bin/activate
  perl jsonValidate.pl ../../json-schemas/0.4.x ../../prototype-data/cameo_prototype_data_fixed
  ```
