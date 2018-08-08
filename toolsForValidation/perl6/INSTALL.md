# EXCELERATE WP2 JSON Schema validation, Perl5+Perl6 hybrid edition (installation)

The dependencies of [jsonValidate](bin/jsonValidate) are declared in [META6.json](META6.json).

* In order to install the dependencies you need `git`. Then, you have to install  [perl6-virtualenv (fixed version)](https://github.com/jmfernandez/perl6-virtualenv/) and [zef](https://github.com/ugexe/zef).

```bash
git clone https://github.com/jmfernandez/perl6-virtualenv.git
perl6-virtualenv/pl6-virt .pl6env
source .pl6env/bin/activate

git clone https://github.com/ugexe/zef.git
cd zef
perl6 -I. bin/zef -to="inst#$VENV" install .
cd ..
```

* You can install the program and its dependencies in the local virtual environment with the next recipe:

```bash
zef -to="inst#$VENV" install .
```
