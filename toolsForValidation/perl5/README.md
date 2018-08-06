# EXCELERATE WP2 JSON Schema validation, Perl edition

All the benchmarking JSON schemas should be compliant with JSON Schema Draft04 specification.

So, the proposed validation programs use libraries compliant with that specification.

* [jsonValidate.pl](jsonValidate.pl) Perl program which depends on a set of Perl modules declared in [cpanfile](cpanfile).
	- In order to install the dependencies you need `cpan`, which is available in many Linux distributions (Ubuntu package `perl`, CentOS package `perl-CPAN`), and also at [App::Cpan](http://search.cpan.org/~andk/CPAN-2.16/) Perl package.
	
	- You can install the program dependencies in a local virtual environment with the next recipe:
	  ```bash
	  # Install App::Virtualenv if it is not installed yet
	  perl -MApp::Virtualenv -c -e '' || cpan -i App::Virtualenv
	  # If past step installs local::lib, modifying your .bashrc, then reload
	  # your profile before following with the next steps
	  virtualenv.pl .plenv
	  source .plenv/bin/activate
	  perl -MApp::cpanminus -c -e '' || cpan -i App::cpanminus
	  cpanm --installdeps .
	  ```
	  
	- The program can be run using next command line, to validate using version 0.4 of the schemas:
	  ```bash
	  perl jsonValidate.pl ../../json-schemas/.0.4.x ../../prototype-data/cameo_prototype_data_fixed
	  ```
