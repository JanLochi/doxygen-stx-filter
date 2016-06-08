Doxygen-STX-Filter
==================

Install
-------
Put the `stxFilter.awk` script somewhere in your PATH, e.g. `/usr/local/bin`

Doxyfile Configuration
----------------------
	EXTENSION_MAPPING = stxp=C++
	FILE_PATTERNS = *.stxp
	FILTER_PATTERNS = *.stxp=stxFilter.awk

Todo
----
* virtual keyword
* preserve line number integrity (for source browser)
* multiple inheritance