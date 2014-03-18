# Some basic parameter tuning
SET max_heap_table_size = 4294967295;
SET tmp_table_size = 4294967295;
SET bulk_insert_buffer_size = 256217728;

# Tables to import data
CREATE TABLE `dbpedia_types_original` (
  `resource` varchar(1000) NOT NULL,
  `type` varchar(1000) NOT NULL);

CREATE TABLE `dbpedia_properties_original` (
  `subject` varchar(1000) NOT NULL,
  `predicate` varchar(1000) NOT NULL,
  `object` varchar(1000) NOT NULL);
  
# Import data
# Note: requires preprocessed data files using NT2CSV.java
LOAD DATA LOCAL INFILE '/Users/nico/Arbeit/hiwi_semantic_web/Type_inference/generate-types/example_data/instance-types.csv' IGNORE INTO TABLE dbpedia_types_original FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\'' LINES TERMINATED BY '\r\n';

LOAD DATA LOCAL INFILE '/Users/nico/Arbeit/hiwi_semantic_web/Type_inference/generate-types/example_data/mappingbased-1000.csv' IGNORE INTO TABLE dbpedia_properties_original FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\'' LINES TERMINATED BY '\r\n';

# Some transformations to allow better indexing - everything is converted to md5 with lookup tables
CREATE TABLE `dbpedia_types_md5` (
  `resource` char(32) NOT NULL,
  `type` char(32) NOT NULL
);
CREATE TABLE `dbpedia_properties_md5` (
  `subject` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `object` char(32) NOT NULL
);
INSERT INTO dbpedia_types_md5 SELECT md5(resource),md5(type) FROM dbpedia_types_original;

ALTER TABLE `dbpedia_types_md5` 
ADD INDEX `idx_dbpedia_types_resource` (`resource` ASC) 
, ADD INDEX `idx_dbpedia_types_type` (`type` ASC);

INSERT INTO dbpedia_properties_md5 SELECT md5(subject), md5(predicate), md5(object) FROM dbpedia_properties_original;

ALTER TABLE `dbpedia_properties_md5` 
ADD INDEX `idx_dbpedia_properties_subject` (`subject` ASC) 
, ADD INDEX `idx_dbpedia_properties_predicate` (`predicate` ASC) 
, ADD INDEX `idx_dbpedia_properties_object` (`object` ASC);

CREATE TABLE `dbpedia_type_to_md5` (
  `type` varchar(1000) NOT NULL,
  `type_md5` char(32) NOT NULL,
  PRIMARY KEY (`type_md5`);
);
INSERT IGNORE INTO dbpedia_type_to_md5 SELECT type,md5(type) FROM dbpedia_types_original;

CREATE TABLE `dbpedia_resource_to_md5` (
  `resource` varchar(1000) NOT NULL,
  `resource_md5` char(32) NOT NULL,
  PRIMARY KEY (`resource_md5`),
  key `idx_resource_to_md5` (`resource`);
);
INSERT IGNORE INTO dbpedia_resource_to_md5 SELECT subject,md5(subject) FROM dbpedia_properties_original;
INSERT IGNORE INTO dbpedia_resource_to_md5 SELECT object,md5(object) FROM dbpedia_properties_original;

CREATE TABLE `dbpedia_predicate_to_md5` (
  `predicate` varchar(1000) NOT NULL,
  `predicate_md5` char(32) NOT NULL,
  PRIMARY KEY `idx_predicate_to_md5_type_md5` (`predicate_md5`)
);
INSERT IGNORE INTO dbpedia_predicate_to_md5 SELECT predicate,md5(predicate) FROM dbpedia_properties_original;

# Compile the statistics
CREATE TABLE `stat_type_count` (
  `type` char(32) NOT NULL,
  `type_count` int(11) NOT NULL,
  KEY `idx_type_count_type` (`type`));

INSERT INTO stat_type_count SELECT type,COUNT(resource) FROM dbpedia_types_md5 GROUP BY (type);

CREATE TABLE `stat_type_apriori_probability` (
  `type` char(32) NOT NULL,
  `probability` float NOT NULL,
  KEY `idx_type_apriori_probability_type` (`type`) 
);

INSERT INTO stat_type_apriori_probability select type,type_count/(select count(resource_md5) from dbpedia_resource_to_md5) AS rel_count from stat_type_count;

CREATE TABLE `stat_resource_predicate_tf` (
  `resource` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `tf` int(11) NOT NULL,
  `outin` int(11) NOT NULL,
  KEY `idx_resource_predicate_tf_resource` (`resource`),
  KEY `idx_resource_predicate_tf_predicate` (`predicate`)
);

INSERT INTO stat_resource_predicate_tf SELECT subject, predicate, COUNT(object),0 FROM dbpedia_properties_md5 GROUP BY subject, predicate;
INSERT INTO stat_resource_predicate_tf SELECT object, predicate, COUNT(subject),1 FROM dbpedia_properties_md5 GROUP BY object, predicate;

CREATE TABLE `stat_type_predicate_percentage` (
  `type` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `outin` int(11) NOT NULL,
  `percentage` float NOT NULL,
  KEY `idx_type_predicate_percentage_type` (`type`),
  KEY `idx_type_predicate_percentage_predicate` (`predicate`)
);

INSERT INTO stat_type_predicate_percentage SELECT types.type, res.predicate, 0, COUNT(subject)/(SELECT COUNT(subject) FROM dbpedia_properties_md5 AS resinner WHERE res.predicate = resinner.predicate)
FROM
dbpedia_properties_md5 AS res,
dbpedia_types_md5 AS types
WHERE
res.subject = types.resource
GROUP BY res.predicate,types.type;

INSERT INTO stat_type_predicate_percentage SELECT types.type, res.predicate, 1, COUNT(object)/(SELECT COUNT(object) FROM dbpedia_properties_md5 AS resinner WHERE res.predicate = resinner.predicate)
FROM
dbpedia_properties_md5 AS res,
dbpedia_types_md5 AS types
WHERE
res.object = types.resource
GROUP BY res.predicate,types.type;

CREATE TABLE `stat_predicate_weight_apriori` (
  `predicate` char(32) NOT NULL,
  `outin` int(11) NOT NULL,
  `weight` float NOT NULL,
  KEY `idx_predicate_weight_apriori_predicate` (`predicate`)
);

INSERT INTO stat_predicate_weight_apriori SELECT predicate,outin,SUM((percentage - probability)*(percentage - probability)) FROM stat_type_predicate_percentage 
LEFT JOIN stat_type_apriori_probability ON stat_type_predicate_percentage.type = stat_type_apriori_probability.type
GROUP BY predicate,outin;

# Materialize the Types
# uses one intermediate table
CREATE  TABLE `dbpedia_untyped_instance` (
  `resource` VARCHAR(1000) NOT NULL ,
  `resource_md5` CHAR(32) NOT NULL );

INSERT INTO dbpedia_untyped_instance SELECT res.resource,res.resource_md5 FROM dbpedia_resource_to_md5 AS res
LEFT JOIN dbpedia_types_md5 as typ ON res.resource_md5=typ.resource
WHERE ISNULL(type);

CREATE TABLE `stat_resource_predicate_type` (
  `resource` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `type` char(32) NOT NULL,
  `tf` float NOT NULL,
  `percentage` float NOT NULL,
  `weight` float NOT NULL,
  KEY `idx_stat_resource_predicate_type` (`resource`,`type`)
);

INSERT INTO stat_resource_predicate_type 
SELECT instance.resource_md5,tf.predicate,perc.type,tf,percentage,weight
FROM dbpedia_untyped_instance as instance
LEFT JOIN stat_resource_predicate_tf as tf on instance.resource_md5 = tf.resource
LEFT JOIN stat_type_predicate_percentage as perc on tf.predicate = perc.predicate and tf.outin = perc.outin 
LEFT JOIN stat_predicate_weight_apriori as weight on tf.predicate = weight.predicate and tf.outin = weight.outin
LEFT JOIN stat_type_apriori_probability as tap on perc.type = tap.type
LEFT JOIN dbpedia_type_to_md5 as t2md5 on tap.type = t2md5.type_md5:

CREATE  TABLE `resulting_types` (
  `resource` VARCHAR(1000) NOT NULL ,
  `type` VARCHAR(1000) NOT NULL ,
  `score` FLOAT NOT NULL );
INSERT INTO resulting_types2 
SELECT resource,type,SUM(tf*percentage*weight)/SUM(tf*weight) AS score FROM stat_resource_predicate_type GROUP BY resource,type HAVING score>=0.05;

# Read types at the threshold you like, e.g.
# SELECT r2md5.resource,t2md5.type FROM resulting_types AS res
# LEFT JOIN dbpedia_resource_to_md5 AS r2md5 ON res.resource=r2md5.resource_md5
# LEFT JOIN dbpedia_type_to_md5 AS t2md5 ON res.type=t2md5.type_md5
# WHERE score>=0.4