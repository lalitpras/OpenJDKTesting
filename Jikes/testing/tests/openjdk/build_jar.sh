#!/bin/bash
#
#  This file is part of the Jikes RVM project (http://jikesrvm.org).
#
#  This file is licensed to You under the Eclipse Public License (EPL);
#  You may not use this file except in compliance with the License. You
#  may obtain a copy of the License at
#
#      http://www.opensource.org/licenses/eclipse-1.0.php
#
#  See the COPYRIGHT.txt file distributed with this work for information
#  regarding copyright ownership.

# This script generates a Jar file from a testing folder structure.
# The general idea is that 
# folder structure must be


#Make sure we're in the folder the script lives in
cd $(dirname $(readlink -f $0))

#Find the java files for testing
FILES=$(find src/ -name "*.java" | sed 's/src\///g')

echo -n "Adding Packagae Information..."
for f in $FILES
do
	#Create a clean version of the file for use later
	cp src/$f src/$f.clean

	#Grab the directory
	DIREC=$(dirname $f)

	#Convert directory to package
	PACK=$(echo $DIREC | sed 's/\//\./g' )
	
	#Add package to beginning of file
	echo "package $PACK;" "$(cat src/$f)" > src/$f
done
echo "Done"

#Get a list of the unique directories
for file in $FILES
do
	direc=$(dirname $file)
	DIRECS="${DIRECS}\n${direc}"

done
DIRECS=$(echo -e $DIRECS | sort | uniq)

#Move through the directories one by one javacing all the java files within

for dir in $DIRECS
do
	echo "Compiling $dir..."
	javac src/$dir/*.java
done


#Setup the Runnner i.e the overall control class
echo -n "Creating Runner Class..."
RUNNER="src/openJDKtests/Runner.java"
rm -f $RUNNER

echo "
/*
 *  This file is part of the Jikes RVM project (http://jikesrvm.org).
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License. You
 *  may obtain a copy of the License at
 *
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  See the COPYRIGHT.txt file distributed with this work for information
 *  regarding copyright ownership.
 */

package openJDKtests;

import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

public class Runner {

	static PrintStream out;
	static PrintStream err;
	static ByteArrayOutputStream boas;
	static PrintStream stream;
	static Map<String, String> results;
	static ArrayList<String> failures;
	static boolean limitedTests;
	static boolean verbose;

	public static void main (String args[]) throws ClassNotFoundException, IllegalArgumentException, SecurityException, IllegalAccessException, InvocationTargetException, NoSuchMethodException{

		// The main map, key is the fully qualified class name, value is the expected output
		results = new HashMap<String, String>();		
		failures = new ArrayList<String>();

		//Verbose output??
		verbose = args.length > 0 ? args[0].toUpperCase().equals(\"-V\") : false;

		// Are we doing a limited test run?
		limitedTests = (args.length > 1 && verbose) || (args.length > 0 && !verbose);

		// Add the tests to the system, all tests are added even on a limited run because it's just adding entries to a map.
		AddTests(results);

		// Store the old output
		out = System.out;
		err = System.err;

		// Setup the new output
		stream = new PrintStream(boas = new ByteArrayOutputStream());
		System.setOut(stream);
		System.setErr(stream);


		try{

			// Main loop
			for (Map.Entry<String, String> entry : results.entrySet()) {

				// Is the test part of the list given (if it exists)
				if (!limitedTests || (limitedTests && Arrays.asList(args).contains(entry.getKey()))){	// \"Never Optimise\"
					Test(entry);
				}
			}
		}

		finally{

			// Reset the output
			System.setOut(out);
			System.setErr(err);
			// Output statistics
			System.out.println(failures.size() + \" tests failed\");

		}
	}

	private static void Test(Map.Entry<String, String> entry){

		String clazz, expected;

		clazz = entry.getKey();
		expected = entry.getValue();    
		Class<?> cls;

		try {
			cls = Class.forName(clazz);
		} catch (ClassNotFoundException e1) {
			printToTerminal(\"Class \" +  clazz + \" not found, please ensure all inputted class names are fully qualified\");
			return;
		}

		String[] blank = {};

		// Start the main method from the class to be tested
		try {
			cls.getMethod(\"main\", String[].class).invoke(null, (Object) blank);
		} catch (InvocationTargetException e){
			Throwable f = e.getCause();
			f.printStackTrace();
		} catch (Exception e){
			e.printStackTrace();
		}

		// Is it a failure??
		if (!boas.toString().equals(expected)){
			failures.add(clazz);
			if (verbose){
				printToTerminal(clazz + \" failed\");
				printToTerminal(\"Expected Output\");
				printToTerminal(expected);
				printToTerminal(\"Recieved Output\");
				printToTerminal(boas.toString());
			} else {
				printToTerminal(clazz + \" failed\");
			}
		} else {
			printToTerminal(clazz + \" passed\");
		}

		boas.reset();

	}

	// Print something directly to the terminal, as opposed to having  the output captured
	// Introduces ton's of unnecessary switching, but it looks cleaner.
	private static void printToTerminal(String output){

		System.setOut(out);
		System.setErr(err);

		System.out.println(output);

		System.setOut(stream);
		System.setErr(stream);

	}
	private static void AddTests(Map<String, String> tests){

" > $RUNNER	

echo "Done"

for f in $FILES
do

	#Grab the directory
	DIREC=$(dirname $f)

	#Convert directory to package
	PACK=$(echo $DIREC | sed 's/\//\./g' )
	
	fullclass=$(echo $f | sed 's/\.java//g' |sed 's/\//\./g')

	class=$(echo $f | sed 's/\.java//g' | sed 's/.*\///g')


	# Run the file, saving ALL output, err and out

	echo -n "Running $fullclass..."
	java -cp src $fullclass > src/$f.expected 2>&1
	echo "Done"

	#There has got to be a better way to do this....	

	output=""
	while IFS= read x
	do	
		x=$(echo "$x" | sed 's/\"/\\\"/g')
   	 	output="${output}${x}\n"

	done < src/$f.expected

	#Add information to file
	
echo	"	tests.put(\"$fullclass\", \"$output\");
" >> $RUNNER
	

done

echo "
	}
	
	
} " >> $RUNNER



#Create the Manifest

echo -n "Creating Manifest..."
rm -f src/manifest

echo "Main-Class: openJDKtests.Runner" > src/Manifest

echo "Done"

# Create the Jar

echo -n "Creating Jar..."
javac $RUNNER

cd src # go down a level into src so jar works properly
#Find the class files for adding to the JAR
CLASSFILES=$(find . -name "*.class")

jar cfm ../OpenJDKTests.jar Manifest $CLASSFILES

rm -f Manifest
echo "Done"

cd ..


#Cleanup
echo -n "Cleaning Up..."

find . -type f -iname \*.class -delete
find . -type f -iname \*.expected -delete


#Put the clean files back
CLEANFILES=$(find . -name "*.clean")

for f in $CLEANFILES
do
	
	f=$(echo $f | sed 's/^\.\///g')
	cleaned=$(echo $f | sed 's/\..*$//g')
	mv $f $cleaned.java
done

rm -f $RUNNER


echo "Finished"






