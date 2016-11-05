Doxygen-STX-Filter
==================

Doxygen filter script for STX, used on Jetter PLCs.\
See <https://www.jetter.de> for more information about the STX language.\
See <http://www.stack.nl/~dimitri/doxygen/helpers.html> for more information
about Doxygen Filters.

Install
-------
**Linux:**\
Put the `stxFilter.awk` script somewhere in your PATH, e.g. `/usr/local/bin`

**Windows:**\
Get the GNU utilities from <http://unxutils.sourceforge.net/> to run awk scripts.

Doxyfile Configuration
----------------------
Change the following parameters in your Doxyfile:

	EXTENSION_MAPPING = stxp=C++
	FILE_PATTERNS = *.stxp
	FILTER_PATTERNS = *.stxp=stxFilter.awk

Possible improvements
---------------------
* Handle the `virtual` keyword
* Preserve line number integrity (for source browser)
* Multiple inheritance
* Preserve function calls in code (for call graph)
