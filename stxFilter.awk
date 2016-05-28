#!/usr/bin/gawk -f
#----------------------------------------------------------------------------
# stxFilter.awk - Doxygen filter script for STX, used on Jetter PLCs
#
# Inspired by the work of Mathias Henze on the Visual Basic filter
#
# Copyright (c) 2015 Jan Lochmatter, jan@janlochmatter.ch
# Bern University of Applied Sciences Engineering and Information Technology
#
# Last change 28. May 2016
#----------------------------------------------------------------------------

BEGIN {
	##########
	# Config #
	##########
	IGNORECASE = 1; # STX keywords are case insensitive
	debug = 1;
	
	
	#############
	# Variables #
	#############
	inDoxyComment = 0;
	inFunction = 0;
	inType = 0;
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
(inType) && (/^\s*end_type;/) {
	if (debug) print "Type end";

	inType = 0;
}

# inside of type


# beginning of type
!(inType) && (/^\s*type/) {
	if (debug) print "#Type begin";

	inType = 1;
}

##########################
# functions outside type #
##########################
# STX: Function DoSomething (Param1 : int, Param2 : int) : int;

# end of function
(inFunction) && (/^\s*end_function;/) {
	if (debug) print "#Function end";
 
	inFunction = 0;
	
	print "}";
	
}

# beginning of function
# match($0, /^\s*function\s+(\w*)[.]?(\w+)\s*[(](.*)[)]/, arr)
!(inFunction) && !(inType) && (/^\s*function\s+\w*[.]?\w+\s*[(].*[)]/) {
	# Check if it is in Class or not
	if (match($0, /^\s*function\s+(\w+)[.](\w+)\s*[(](.*)[)]/, arr)) {
		# with class
		className = arr[1];
		funcName = arr[2];
		funcParam = arr[3];
	} else {
		match($0, /^\s*function\s+(\w+)\s*[(](.*)[)]/, arr)
		# no class
		className = "";
		funcName = arr[1];
		funcParam = arr[2];
	}
	
	# Look for return type TODO: Handle pointers
	if (match($0, /[:]\s*(\w+)\s*[;]\s*$/, arr)) {
		retType = arr[1];
	} else {
		retType = "void";
	}
	
	inFunction = 1;

	if (debug) print "#RetType:", retType, "Class:", className, "Function:", funcName, "#Parameters:", funcParam;
	
	# Print return type, name and '('
	printf("%s %s(", retType, funcName);

	# Split parameter list at , or :
	#gsub(/\s+/, "", funcParam); # Remove whitespace
	nParams = split(funcParam, funcParams, /[,:]/);
	
	# Look for pointers
	replacePointers(funcParams);
	
	# Remove whitespace
	for (i in funcParams) {
		gsub(/\s+/, "", funcParams[i]);
	}

	# Rearrange parameters
	for (i in funcParams) {
		if ((i % 2) == 0) {
			printf("%s %s", funcParams[i], funcParams[i-1]);
			if (i >= nParams) { # Check if last Param
				print ") {";
			} else {
				printf(", ");
			}
		}
	}
	
	# For func with no parameters
	if (nParams == 0) {
		print ") {";
	}
}

########################## Helper Functions ##########################

# Replace the STX 'pointer to' with a '*' and move it to the end of the data type name
# param params: array containing parameter pairs
function replacePointers(params) {
	for (i in params) {
		if (sub("pointer to", "", params[i])) {
			# Found, so add a '*' at the end
			#if (debug) print "#Found a pointer, inserted *";
			params[i] = params[i]"*";
		}
	}
}