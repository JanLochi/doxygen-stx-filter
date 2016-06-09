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
# Last change 9. June 2016
#----------------------------------------------------------------------------

BEGIN {
	##########
	# Config #
	##########
	IGNORECASE = 1;        # STX keywords are case insensitive
	debug = 0;             # Enable / disable debug output.
	indentStr = "    ";    # A string which will be used as indent
	taskVarsAsMember = 1;  # Treat variables in Tasks as members
	allPreprocessor = 1;   # Print all lines starting with '#' (otherwise only #include)


	#############
	# Variables #
	#############
	currentClassName = "";
	inDoxyComment = 0;
	inFunction = 0;
	inSub = 0;
	inType = 0;
	inClass = 0;
	inInterface = 0;
	inTask = 0;
	inVar = 0;
	inConst = 0;
	inEnum = 0;
	inStruct = 0;
	inMacro = 0;
}

############
# comments #
############

# end of comment (/\*\)$/)
(inDoxyComment) && (/\*\)$/) {
	if (debug) print "#Comment end";
	printIndent();
	print " */";
	inDoxyComment = 0;
}

# inside of comment (set indent to one space)
(inDoxyComment) && (/.*/) {
	commentLine = $0;
	sub(/^\s*/, " ", commentLine);
	printIndent();
	print commentLine;

	# No further processing in comment
	next;
}

# beginning of comment
!(inDoxyComment) && (/^\s*\(\*\*$/) {
	if (debug) print "#Comment begin";

	printIndent();
	print "/**";
	inDoxyComment = 1;

	# No further processing in comment
	next;
}

################
# preprocessor #
################

# meaning the statements starting with '#', \x23 is the '#'

# includes
(!allPreprocessor) && (/^\s*\x23include/) {
	print $0;
	next; # no further pattern matching on this line
}

# every line with '#', and multiple line macros
(allPreprocessor) && ((/^\s*\x23/) || (inMacro)) {
	line = $0;

	# Replace (** and *) for inline documentation
	sub(/[(][*][*]/, "/**", line);
	sub("*)", "*/", line);

	print line;
	
	# Macro spans multiple lines?
	if (match($0, /[\\]\s*$/)) {
		inMacro = 1;
	} else {
		inMacro = 0;
	}
	next; # no further pattern matching on this line
}

########
# vars #
########

# end of var
(inVar) && (/^\s*end_var/) {
	if (debug) print "#Var end";

	inVar = 0;
}

# print global vars
(inVar) && (!inFunction) && (!inTask) && match($0, /^\s*(\w+)\s*[:]\s*([^;]+)[;]/, arr) {
	varName = arr[1];
	varType = arr[2];

	# Move constructor paramters to the varName
	if (match($0, /([(].+[)])/, arr)) {
		sub(/[(].+[)]/, "", varType); # strip from type
		varName = varName arr[1]; # Append to name
	}

	# print the constants with the C++ auto keyword and inline documentation
	printf("%s %s; %s\n", varType, varName, searchMemberDoc($0));
}

# beginning of var
(!inVar) && (!inType) && (/^\s*var/) {
	if (debug) print "#Var begin";

	inVar = 1;
}

#############
# constants #
#############

# end of const
(inConst) && (/^\s*end_const\s*[;]?\s*$/) {
	if (debug) print "#Const end";

	inConst = 0;
}

# print global consts
(inConst) && (!inFunction) && match($0, /^\s*(\w+)\s*[=]\s*([^;]+)[;]/, arr) {
	constName = arr[1];
	constValue = arr[2];

	# print the constants with the C++ auto keyword and inline documentation
	printf("const auto %s = %s; %s\n", constName, constValue, searchMemberDoc($0));
}

# beginning of const
(!inConst) && (!inType) && (/^\s*const\s*$/) {
	if (debug) print "#Const begin";

	inConst = 1;
}

#########
# types #
#########

# end of type
(inType) && (/^\s*end_type/) {
	if (debug) print "#Type end";

	inType = 0;
}

# beginning of type
!(inType) && (/^\s*type/) {
	if (debug) print "#Type begin";

	inType = 1;
}

# look for typedefs inside of type
(inType) && (!inClass) && (!inEnum) && (!inStruct) && match($0, /^\s*(\w+)\s*[:]\s*([^;]+)\s*[;]/, arr) {
	if (debug) print "#Typedef found";
	pair = arr[1]" : "arr[2];

	printf("typedef %s;\n", processPair(pair));
}

#########
# tasks #
#########

# treat a task like a class

# end of task
(inTask) && (/^\s*end_task/) {
	if (debug) print "#Task end";

	inTask = 0;
	print "};\n";
}

# in task, print variables as members
(inTask) && (inVar) && (taskVarsAsMember) && (match($0, /^\s*(\w+\s*[:]\s*.+)\s*[;]/, arr)) {
	pair = arr[1];
	printf("%s%s; %s\n", indentStr, processPair(pair), searchMemberDoc($0));
}

# beginning of task, skip forward declaration (extract task name)
(!inTask) && (match($0, /^\s*task\s+(\w+)\s*/, arr)) {
	if (match($0, /forward[;]\s*$/)) {
		if (debug) print "#Skip task forward decl.";
	} else {
		if (debug) print "#Task begin";
		taskName = arr[1];
		inTask = 1;
	
		# Print a class header with private members
		printf("class %s {\nprivate:\n", taskName);
	}
}

########################
# classes & interfaces #
########################

# treat a interface like a class

# end of interface
(inInterface) && (/^\s*end_interface/) {
	if (debug) print "#Interface end";

	inClass = 0;
	inInterface = 0;
	print "};\n";
}

# end of class
(inClass) && (/^\s*end_class/) {
	if (debug) print "#Class end";

	inClass = 0;
	print "};\n";
}

# beginning of class or interface
(inType) && (!inClass) && ((/^\s*(\w+)\s*[:]\s*class/) || (/^\s*(\w+)\s*[:]\s*interface/)) {
	currentClassName = $1;
	if (debug) print "#Class begin, name:", currentClassName;

	# Check if it is a interface
	if (match($0, /interface/)) {
		inInterface = 1;
	} else {
		inInterface = 0;
	}

	# Check if there is a inheritance
	if (match($0, /[(](.+)[)]/, arr)) {
		printf("class %s : public %s {\n", currentClassName, arr[1]);
	} else {
		printf("class %s {\n", currentClassName);
	}

	# Make interface members public
	if (inInterface) {
		print "public:";
	}
	
	inClass = 1;
}

# visibility keywords
(inClass) && (/^\s*public/) {
	print "public:";
}
(inClass) && (/^\s*private/) {
	print "private:";
}
(inClass) && (/^\s*protected/) {
	print "protected:";
}

# attributes (also look for in line documentation
(inClass) && match($0, /^\s*(\w+\s*[:]\s*.+)\s*[;]/, arr) {
	pair = arr[1];
	#printf("%s%s;\n", indentStr, processPair(pair));
	printf("%s%s; %s\n", indentStr, processPair(pair), searchMemberDoc($0));
}

################
# enumerations #
################

# end of enum
(inEnum) && match($0, /^\s*([^)]*)[)][;]/, arr) {
	if (debug) print "#Enum end";

	inEnum = 0;
	literal = arr[1];
	printf("%s%s %s\n};\n\n", indentStr, literal, searchMemberDoc($0));
}


# in enum
(inEnum) && match($0, /^\s*([^,]*)[,]/, arr) {
	literal = arr[1];
	printf("%s%s, %s\n", indentStr, literal, searchMemberDoc($0));
}

# beginning of enum
(inType) && (!inEnum) && match($0, /^\s*(\w+)\s*[:]\s*enum\s*[(](.*)/, arr) {
	if (debug) print "#Enum begin";

	inEnum = 1;
	enumName = arr[1];
	remainingLine = arr[2];

	# Print enum beginning
	printf("enum %s {\n", enumName);

	# Print remaining line, if containing an enum literal (including documentation, if present)
	if(match(remainingLine, /^(.+?)[,]/, arr)) {
		literal = arr[1];
		printf("%s%s, %s\n", indentStr, literal, searchMemberDoc(remainingLine));
	}
}

###########
# structs #
###########

# end of struct
(inStruct) && (/^\s*end_struct/) {
	if (debug) print "#Struct end";

	inStruct = 0;
	print "};\n";
}


# in struct
(inStruct) && match($0, /^\s*([^;]*)[;]/, arr) {
	printf("%s%s; %s\n", indentStr, processPair(arr[1]), searchMemberDoc($0));
}

# beginning of struct
(inType) && (!inStruct) && match($0, /^\s*(\w+)\s*[:]\s*struct/, arr) {
	if (debug) print "#Struct begin";

	inStruct = 1;
	structName = arr[1];

	# Print struct beginning
	printf("struct %s {\n", structName);
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
	# Check if function is inside or outside of class definition
	if (match($0, /^\s*function\s+(\w+)[.](\w+)\s*[(](.*)[)]/, arr)) {
		# is outside of class definition
		className = arr[1]"::";
		funcName = arr[2];
		funcParameters = arr[3];
	} else {
		match($0, /^\s*function\s+(\w+)\s*[(](.*)[)]/, arr)
		# is inside of class definition, or not a member of any class
		className = "";
		funcName = arr[1];
		funcParameters = arr[2];
	}

	# Make indent if in class decl.
	printIndent();

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

	# Check if function is a constructor
	if (funcName == currentClassName) {
		retType = ""; # Constructor has no return type
	} else {
		# append space
		retType = (retType " ");
	}

	if (debug) print "#RetType:", retType, "Class:", className, "Function:", funcName, "#Parameters:", funcParameters;
					 
	# If this is a interface method, make it lika a C++ abstract class (virtual int myFunc() = 0;)
	if (inInterface) {
		printf("virtual ");
	}

	# Print return type, name and '('
	printf("%s%s%s(", retType, className, funcName); # space after retType is appended above

	# Split parameter list at ,
	nParams = split(funcParameters, pairs, /[,]/);

	# Process all pairs
	for (i in pairs) {
		printf("%s", processPair(pairs[i]));
		if (i < nParams) {
			printf(", ");
		}
	}

	# Check if part of type declaration, and if it is a interface method
	if (inType && inInterface) {
		# Abstract prototype
		print ") = 0;";
		inFunction = 0;
	} else if (inType) {
		# Prototype
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
	if (debug) print "#Sub end";

	inSub = 0;
	print "}\n";
}

# beginning of sub
(!inSub) && (/^\s*sub\s+\w*[.]?\w+\s*[;]?\s*$/) {
	# Check if outside class
	if (match($0, /^\s*sub\s+(\w+)[.](\w+)/, arr)) {
		# is member
		className = arr[1]"::";
		funcName = arr[2];
		funcParam = arr[3];
	} else {
		match($0, /^\s*sub\s+(\w+)/, arr)
		# check if inside class or without class
		className = "";
		funcName = arr[1];
		funcParam = arr[2];
	}

	if (debug) print "#Sub begin"

	# Make indent if in class decl.
	if (inClass) {
		printf("%s", indentStr);
	}

	# Returntype is void or nothing for constructors
	if (currentClassName == funcName) {
		retType = "";
	} else {
		retType = "void ";
	}

	# Check if part of type declaration
	if (inType) {
		# Just a prototype
		printf("%s%s%s();\n", retType, className, funcName);
		inSub = 0;
	} else {
		# Code follows
		printf("%s%s%s() {\n", retType, className, funcName);
		inSub = 1;
	}
}

########################## Helper Functions ##########################

# Look for inline member documentation
function searchMemberDoc(line) {
	if (match(line, /\(\*\*[<]\s*(.+)\s*\*\)$/, arr)) {
		return "/**< "arr[1]" */";
	} else {
		return "";
	}
}

# Process a STX designator and type pair (myCounter : int) and convert it. Replace array and pointer syntax
function processPair(pair) {
	# TODO: 'any ref'

	# Remove possible ';'
	gsub(/[;]/, "", pair);

	# Separate at ':'
	split(pair, splitted, /[:]/);
	designator = splitted[1];
	type = splitted[2];

	if (debug) print "\n#Pair:", pair, "type:", type, "designator:", designator;

	# Look for arrays like 'array[6] of int'
	if (match(type, /array\s*[[](\w+)[]]\s*of\s*(.+)\s*/, arr)) {
		arrayLength = arr[1];
		type = arr[2];
		isArray = 1;
	} else {
		isArray = 0;
	}

	# Look for 'index of', is used for pointers to registers, no C++ equivalent
	sub("index of ", "", type)

	# Look for pointers 'pointer to'
	if (sub("pointer to ", "", type)) {
		pointer = "*";
	} else {
		pointer = "";
	}

	# Look for ref and const
	if (sub("ref ", "", designator)) {
		reference = "&";
	} else {
		reference = "";
	}
	if (sub("const ", "", designator)) {
		const = "const ";
	} else {
		const = "";
	}

	# Remove whitespace
	gsub(/\s+/, "", type);
	gsub(/\s+/, "", designator);

	# Return reassembled pair
	if (isArray) {
		return (const type" "pointer reference designator"["arrayLength"]");
	} else {
		return (const type" "pointer reference designator);
	}
}

# Prints indent at variable depth (only class so far)
function printIndent() {
	if (inClass) {
		printf("%s", indentStr);
	}
}