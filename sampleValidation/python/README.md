# EXCELERATE WP2 JSON Schema validation, Python edition

All the benchmarking JSON schemas should be compliant with JSON Schema Draft04 specification.

So, the proposed validation program uses libraries compliant with that specification.

* [jsonValidate.py](jsonValidate.py) Python program which depends on a set of Python modules declared in [requirements.txt](requirements.txt).
	- In order to install the dependencies you need `pip` and `virtualenv`. `pip` is available in many Linux distributions (Ubuntu package `python-pip`, CentOS EPEL package `python-pip`), and also as [pip](https://pip.pypa.io/en/stable/) Python package.
	
	- Although `virtualenv` is available in some Linux distributions, it is usually installed either standalone (see [this](https://www.dabapps.com/blog/introduction-to-pip-and-virtualenv-python/)), or through `pip`. Next instructions will work on Ubuntu:
	  ```bash
	  sudo apt-get install python-pip python-dev build-essential
	  sudo pip install virtualenv virtualenvwrapper
	  sudo pip install --upgrade pip
	  ```
	
	- The creation of a virtual environment and installation of the dependencies in that environment is done running:
	  ```bash
	  virtualenv .pyenv
	  source .pyenv/bin/activate
	  pip install -r requirements.txt
	  ```
	  
	- The creation of a virtual environment for a concrete python version would be:
	  ```bash
	  virtualenv -p /usr/bin/python3 .pyenv
	  source .pyenv/bin/activate
	  pip install -r requirements.txt
	  ```
	  
	- The program can be run using next command line:
	  ```bash
	  python jsonValidate.py ../../json-schemas ../../prototype-data/cameo_prototype_data_fixed
	  ```
