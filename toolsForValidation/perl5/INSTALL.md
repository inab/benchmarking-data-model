# EXCELERATE WP2 JSON Schema validation, Perl edition (installation)

The dependencies of [jsonValidate.pl](jsonValidate.pl) are declared in [cpanfile](cpanfile).

* In order to install the dependencies you need `cpan`, which is available in many Linux distributions (Ubuntu package `perl`, CentOS package `perl-CPAN`), and also at [App::Cpan](http://search.cpan.org/~andk/CPAN-2.16/) Perl package.

* You can install the program dependencies in the `deps` directory with the next recipe:
  ```bash
  perl -MCarton -c -e '' || cpan -i Carton
  carton install -p deps --deployment
  ```
