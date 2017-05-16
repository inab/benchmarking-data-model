# EXCELERATE WP2 JSON Schema validation, Perl edition

All the benchmarking JSON schemas should be compliant with JSON Schema Draft04 specification.

So, the proposed validation programs use libraries compliant with that specification.

* [jsonValidate.pl](jsonValidate.pl) Perl program which depends on a set of Perl modules declared in [cpanfile](cpanfile).
	- In order to install the dependencies you need `cpanm`, which is available in many Linux distributions (Ubuntu package `cpanminus`, CentOS EPEL package `perl-App-cpanminus`), and also at [App::cpanminus](http://search.cpan.org/~miyagawa/App-cpanminus-1.7043/) Perl package.
	
	- The installation of the dependencies in the program's directory is done running:
	  ```bash
	  cpanm -L perllibs --installdeps .
	  ```
	  
	- The program can launched using next command line:
	  ```bash
	  perl jsonValidate.pl ../../json-schemas ../../cameo_prototype_data_fixed
	  ```
