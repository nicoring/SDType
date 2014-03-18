Generating Missing Types for DBpedia
------------------------------------

This package of scripts allows to generate types for untyped instances in DBpedia, as described in [1]. To produce the types, please perform the following steps:

1. Get the mappingbased-properties.nt and instance-types.nt files from the DBpedia download page [2], and store them in a local folder.

2. Put the local folder name in the Java program NT2CSV.java, and run the Java program. It produces two output files.

3. Create a MySQL database.

4. Run the script generate_types.sql on the database.

5. The last line of the aforementioned script is commented out, it shows you how to read out the generated types.

The whole SQL script may run up to 24h, give or take a few.

A few hints on configuration parameters for MySQL:
* If the import from files does not work, start mysql with the parameter --local-infile
* Set the config variable innodb_buffer_pool_size to 4294967295 in the MySQL config file

[1] Paulheim and Bizer: Type Inference on Noisy RDF Data. In: International Semantic Web Conference (ISWC), 2013.
[2] http://wiki.dbpedia.org/Downloads