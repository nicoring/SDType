Generating Missing Types for DBpedia
------------------------------------

This is based on the package, which can be found here http://wifo5-21.informatik.uni-mannheim.de:8080/DBpediaTypeCompletionService/ 

This package of scripts allows to generate types for untyped instances in DBpedia, as described in [Paulheim and Bizer: Type Inference on Noisy RDF Data. In: International Semantic Web Conference (ISWC), 2013][1]. To produce the types, please perform the following steps:

1. Run the Shell Script getcsv.sh this will produce two files

3. Create a MySQL database.

4. Run the script generate_types.sql on the database.

5. The last line of the aforementioned script is commented out, it shows you how to read out the generated types and create and how to create an output file.

The whole SQL script may run up to 24h, give or take a few.

A few hints on configuration parameters for MySQL:
* If the import from files does not work, start mysql with the parameter --local-infile
* Set the config variable innodb_buffer_pool_size to 4294967295 in the MySQL config file

[1]: http://www.heikopaulheim.com/docs/iswc2013.pdf
[2]: http://wiki.dbpedia.org/Downloads
