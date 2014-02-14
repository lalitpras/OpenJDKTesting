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

#Setup the Buildfile
BUILDFILE="build_testing.xml"

rm $BUILDFILE

#Find the java files for testing
FILES=$(find src/ -name "*.java" | sed 's/src\///g')

#Get a list of the unique directories
for file in $FILES
do
	direc=$(dirname $file)
	DIRECS="${DIRECS}\n${direc}"

done

DIRECS=$(echo -e $DIRECS | sort | uniq)

echo "Generating build_testing.xml"

# Add headers
echo "<!--
 ~  This file is part of the Jikes RVM project (http://jikesrvm.org).
 ~
 ~  This file is licensed to You under the Eclipse Public License (EPL);
 ~  You may not use this file except in compliance with the License. You
 ~  may obtain a copy of the License at
 ~
 ~      http://www.opensource.org/licenses/eclipse-1.0.php
 ~
 ~  See the COPYRIGHT.txt file distributed with this work for information
 ~  regarding copyright ownership.
 -->" >> $BUILDFILE

echo "<project name=\"openjdk_testing\" default=\"test\" basedir=\".\">

	<import file=\"../../../build/tests.xml\" />
	
	<property name=\"main.java\" location=\"src\" />

	<property name=\"build.classes\" location=\"\${build.tests.dir}/classes\" />
	
	<property name=\"test.class.path\" value=\"\${build.classes}\" />
	
	<!-- Compile -->
	
	<target name=\"compile\" depends=\"init\">
" >> $BUILDFILE

#Create the section to javac the files
for dir in $DIRECS
do
		echo "		<mkdir dir=\"\${build.classes}/$dir\" />" >> $BUILDFILE
		echo "		<javac srcdir=\"\${main.java}/$dir\" destdir=\"\${build.classes}/$dir\" debug=\"true\" source=\"1.6\" target=\"1.6\" includeantruntime=\"false\" includes=\"*.java\"/>
" >> $BUILDFILE
	

done


echo "	</target>
" >> $BUILDFILE

echo "	<!-- Test --> 
		
<target name=\"test\" depends=\"compile\">" >> $BUILDFILE

echo "		<!-- Baseline -->" >> $BUILDFILE

#Run the Control

for file in $FILES
do
		dir=$(dirname $file)
		name=$(basename $file | sed 's/.java//g')
 		echo "		<!-- $file -->" >> $BUILDFILE
		echo "		<echo message=\"Running $file on Hotspot\"/>" >> $BUILDFILE
		echo "		<java classname=\"$name\" output=\"src/$dir/$name.expected\" fork=\"true\">
				<classpath>
				<pathelement location=\"\${build.classes}/$dir/\" />
			</classpath>
		</java>
" >> $BUILDFILE

done	

echo "		<!-- Comparison -->" >> $BUILDFILE

echo "		<startResults/>" >> $BUILDFILE


#Run Jikes

for file in $FILES
do
	dir=$(dirname $file)
	name=$(basename $file | sed 's/.java//g')

	echo "			<runCompareTest tag=\"$name\" class=\"$name\" expecteddir=\"\${main.java}/$dir\" classpath=\"\${build.classes}/$dir\"/>" >> $BUILDFILE

done

echo "		<finishResults/>" >> $BUILDFILE

echo "		</target>


</project>" >> $BUILDFILE

echo "Completed"

