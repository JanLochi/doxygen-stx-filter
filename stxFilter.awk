#!/usr/bin/gawk -f
#----------------------------------------------------------------------------
# stxFilter.awk - Doxygen filter script for STX, used on Jetter PLCs
#
# Inspired by the work of Mathias Henze on the Visual Basic filter
#
# Copyright (c) 2015 Jan Lochmatter, jan@janlochmatter.ch
# Bern University of Applied Sciences Engineering and Information Technology
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Last change 7. June 2016
#----------------------------------------------------------------------------

BEGIN {
	##########
	# Config #
	##########
	IGNORECASE = 1; # STX keywords are case insensitive
	debug = 0;
	indentStr = "    ";


	#############
	# Variables #
	#############
	inDoxyComment = 0;
	inFunction = 0;
	inSub = 0;
	inType = 0;
	inClass = 0;
}

############
# comments #
############

# end of comment (/\*\)$/)
(inDoxyComment) && (/\*\)$/) {
	if (debug) print "#Comment end";

	print "*/";
	inDoxyComment = 0;
}

# inside of comment
(inDoxyComment) && (/.*/) {
	print $0;
}

# beginning of comment
!(inDoxyComment) && (/^\s*\(\*\*$/) {
	if (debug) print "#Comment begin";

	print "/**";
	inDoxyComment = 1;
}

############
# includes #
############
(/^\s*\x23include/) {
	print $0;
}

#########
# types #
#########

# end of type
(inType) && (/^\s*end_type/) {
	if (debug) print "Type end";

	inType = 0;
}

# inside of type


# beginning of type
!(inType) && (/^\s*type/) {
	if (debug) print "#Type begin";

	inType = 1;
}

###########
# classes #
###########

# end of class
(inClass) && (/^\s*end_class/) {
	if (debug) print "#Class end";

	inClass = 0;
	print "};\n";
}

# beginning of class
(inType) && (!inClass) && (/^\s*(\w+)\s*[:]\s*class/) {
	# Check if there is a inheritance TODO: Interfaces
	if (match($0, /[(](.+)[)]/, arr)) {
		printf("class %s : public %s {\n", $1, arr[1]);
	} else {
		printf("class %s {\n", $1);
	}

	inClass = 1;
}

# visibility keywords
(inClass) && (/public/) {
	print "public:";
}
(inClass) && (/private/) {
	print "private:";
}
(inClass) && (/protected/) {
	print "protected:";
}

# attributes
(inClass) && match($0, /^\s*(\w+\s*[:]\s*.+)\s*[;]/, arr) {
	pair = arr[1];
	printf("%s%s;\n", indentStr, processPair(pair));
}

#############
# functions #
#############
# STX: Function DoSomething (Param1 : int, Param2 : int) : int;

# end of function
(inFunction) && (/^\s*end_function/) {
	if (debug) print "#Function end";

	inFunction = 0;
	print "}\n";
}

# beginning of function
!(inFunction) && (/^\s*function\s+\w*[.]?\w+\s*[(].*[)]/) {
	# Check if function is a member
	if (match($0, /^\s*function\s+(\w+)[.](\w+)\s*[(](.*)[)]/, arr)) {
		# is member
		className = arr[1]"::";
		funcName = arr[2];
		funcParameters = arr[3];
	} else {
		match($0, /^\s*function\s+(\w+)\s*[(](.*)[)]/, arr)
		# no member
		className = "";
		funcName = arr[1];
		funcParameters = arr[2];
	}

	# Make indent if in class decl.
	if (inClass) {
		printf("%s", indentStr);
	}

	# Look for return type
	if (match($0, /[:]\s*pointer\s+to\s+(\w+)\s*[;]\s*$/, arr)) {
		# Is pointer type
		retType = arr[1]" *";
	} else if (match($0, /[:]\s*(\w+)\s*[;]\s*$/, arr)) {
		# No pointer
		retType = arr[1];
	} else {
		retType = "void";
	}

	if (debug) print "#RetType:", retType, "Class:", className, "Function:", funcName, "#Parameters:", funcParameters;

	# Print return type, name and '('
	printf("%s %s%s(", retType, className, funcName);

	# Split parameter list at ,
	nParams = split(funcParameters, pairs, /[,]/);

	# Process all pairs
	for (i in pairs) {
		printf("%s", processPair(pairs[i]));
		if (i < nParams) {
			printf(", ");
		}
	}

	# Check if part of type declaration
	if (inType) {
		# Just a prototype
		print ");";
		inFunction = 0;
	} else {
		# Code follows
		print ") {";
		inFunction = 1;
	}
}

#######
# sub #
#######
# end of sub
(inSub) && (/^\s*end_sub;/) {
	if (debug) print "Sub end";

	inSub = 0;
	print "}\n";
}

# beginning of sub
(!inSub) && (/^\s*sub\s+\w*[.]?\w+\s*[;]?\s*$/) {
	# Check if member
	if (match($0, /^\s*sub\s+(\w+)[.](\w+)/, arr)) {
		# is member
		className = arr[1]"::";
		funcName = arr[2];
		funcParam = arr[3];
	} else {
		match($0, /^\s*sub\s+(\w+)/, arr)
		# no member
		className = "";
		funcName = arr[1];
		funcParam = arr[2];
	}

	if (debug) print "#In sub"

	# Make indent if in class decl.
	if (inClass) {
		printf("%s", indentStr);
	}

	# Check if part of type declaration
	if (inType) {
		# Just a prototype
		printf("void %s%s();\n", className, funcName);
		inSub = 0;
	} else {
		# Code follows
		printf("void %s%s() {\n", className, funcName);
		inSub = 1;
	}
}

########################## Helper Functions ##########################

# Replace the STX 'pointer to' with a '*' and move it to the end of the data type name
# params: array containing parameter pairs
function replacePointers(params) {
	for (i in params) {
		if (sub("pointer to", "", params[i])) {
			# Found, so add a '*' at the end
			#if (debug) print "#Found a pointer, inserted *";
			params[i] = params[i]"*";
		}
	}
}

# Replace the STX array type
# param: Datatype statement like 'array[6] of int'
function replaceArray(param) {
	if (match(param, /array\s*[[](\w+)[]]\s*of\s*(.+)/, arr)) {
		return arr[2]"["arr[1]"]";
	} else {
		return param;
	}
}

# Process a STX designator and type pair (myCounter : int) and convert it. Replace array and pointer syntax
function processPair(pair) {
	# TODO: 'ref'

	# Remove possible ';'
	gsub(/[;]/, "", pair);

	# Separate at ':'
	split(pair, splitted, /[:]/);
	designator = splitted[1];
	type = splitted[2];

	# Look for arrays like 'array[6] of int'
	if (match(type, /array\s*[[](\w+)[]]\s*of\s*(.+)\s*/, arr)) {
		arrayLength = arr[1];
		type = arr[2];
		isArray = 1;
	} else {
		isArray = 0;
	}

	# Look for pointers 'pointer to'
	if (sub("pointer to", "", type)) {
		pointer = "*";
	} else {
		pointer = "";
	}

	# Remove whitespace
	gsub(/\s+/, "", type);
	gsub(/\s+/, "", designator);

	# Return reassembled pair
	if (isArray) {
		return type" "pointer designator"["arrayLength"]"
	} else {
		return type" "pointer designator
	}
}