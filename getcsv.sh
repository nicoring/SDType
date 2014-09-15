#!/bin/bash
read -p "Do you want to download your data from the 'http://wiki.dbpedia.org/Downloads'? (y/n): " answerUrl
if [[ "$answerUrl" == "y" ]];
	then
		echo "Please enter your language code"
		echo "available are: en, ca, de, es, eu, fr, id, it, ja, ko, nl, pl, pt, ru, tr" 
		read languageCode

		UrlProperties="http://downloads.dbpedia.org/3.9/$languageCode/mappingbased_properties_$languageCode.nt.bz2"
		UrlTypes="http://downloads.dbpedia.org/3.9/$languageCode/instance_types_$languageCode.nt.bz2"
	else
		echo "Then please enter the URL from where you want to download your mappingbased_properties: "
		read UrlProperties
		echo "And the URL where you want to download the instance_types: "
		read UrlTypes
fi

read -p "Should the files be stored in the current directory?(y/n): " answerPath
if [[ "$answerPath" == "y" ]];
	then
		path=$PWD
	else
		echo "Then please enter the Path where the files should be stored: " 
		read path
fi

echo "The Urls to download the mappingbased_properties and the instance_types:"
echo $UrlProperties
echo $UrlTypes
echo "The path, where the files will be stored:"
echo $path
read -p "Continue? (y/n): " answerContinue

if [[ "$answerContinue" != "y" ]]; then
	exit
fi 

echo "Ok, this could take a while"
rm -f mappingbased_properties_$languageCode.csv instance_types_$languageCode.csv
echo "Generating mappingbased_properties_$languageCode.csv"
curl -# $UrlProperties | bzip2 -d | grep -Ev '^#'| native2ascii -reverse -encoding utf8 | awk '{if(gsub(/> </,"> <",$0)==2) print($0)}' | sed "s/> </','/g;s/^</'/g;s/> \./'/g" > $path/mappingbased_properties_$languageCode.csv
echo "Generating instance_types_$languageCode.csv"
curl -# $UrlTypes | bzip2 -d | grep -Ev '^#' | native2ascii -reverse -encoding utf8 | sed "s/^</'/g;s/> <.*> </','/g;s/> ./'/g" > $path/instance_types_$languageCode.csv