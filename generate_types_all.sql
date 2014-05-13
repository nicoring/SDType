# Some basic parameter tuning
SET max_heap_table_size = 4294967295;
SET tmp_table_size = 4294967295;
SET bulk_insert_buffer_size = 256217728;

# Prefix for different datasets
# replace all 'prefix' with the language specific prefix like 'en'

# Tables to import data
/*DROP TABLE IF EXISTS `prefix_dbpedia_types_original`;
CREATE TABLE `prefix_dbpedia_types_original` (
  `resource` varchar(1000) NOT NULL,
  `type` varchar(1000) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `prefix_dbpedia_properties_original`;
CREATE TABLE `prefix_dbpedia_properties_original` (
  `subject` varchar(1000) NOT NULL,
  `predicate` varchar(1000) NOT NULL,
  `object` varchar(1000) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  
# Import data
# Note: requires preprocessed data files using getcsv.sh

LOAD DATA INFILE '/home/nico/DSType/dataset/instance_types_prefix.csv' IGNORE INTO TABLE prefix_dbpedia_types_original FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\'' LINES TERMINATED BY '\n';

LOAD DATA INFILE '/home/nico/DSType/dataset/mappingbased_properties_prefix.csv' IGNORE INTO TABLE prefix_dbpedia_properties_original FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\'' LINES TERMINATED BY '\n';

# Some transformations to allow better indexing - everything is converted to md5 with lookup tables
DROP TABLE IF EXISTS `prefix_dbpedia_types_md5`;
CREATE TABLE `prefix_dbpedia_types_md5` (
  `resource` char(32) NOT NULL,
  `type` char(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `prefix_dbpedia_properties_md5`;
CREATE TABLE `prefix_dbpedia_properties_md5` (
  `subject` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `object` char(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_dbpedia_types_md5 SELECT md5(resource),md5(type) FROM  prefix_dbpedia_types_original;

ALTER TABLE `prefix_dbpedia_types_md5` 
ADD INDEX `idx_dbpedia_types_resource` (`resource` ASC),
ADD INDEX `idx_dbpedia_types_type` (`type` ASC);

INSERT INTO prefix_dbpedia_properties_md5 SELECT md5(subject), md5(predicate), md5(object) FROM prefix_dbpedia_properties_original;

ALTER TABLE `prefix_dbpedia_properties_md5` 
ADD INDEX `idx_dbpedia_properties_subject` (`subject` ASC),
ADD INDEX `idx_dbpedia_properties_predicate` (`predicate` ASC),
ADD INDEX `idx_dbpedia_properties_object` (`object` ASC);

DROP TABLE IF EXISTS `prefix_dbpedia_type_to_md5`;
CREATE TABLE `prefix_dbpedia_type_to_md5` (
  `type` varchar(1000) NOT NULL,
  `type_md5` char(32) NOT NULL,
  PRIMARY KEY (`type_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO prefix_dbpedia_type_to_md5 SELECT type,md5(type) FROM prefix_dbpedia_types_original;

DROP TABLE IF EXISTS `prefix_dbpedia_resource_to_md5`;
CREATE TABLE `prefix_dbpedia_resource_to_md5` (
  `resource` varchar(1000) NOT NULL,
  `resource_md5` char(32) NOT NULL,
  PRIMARY KEY (`resource_md5`),
  key `idx_resource_to_md5` (`resource`(255))
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO prefix_dbpedia_resource_to_md5 SELECT subject,md5(subject) FROM prefix_dbpedia_properties_original;
INSERT IGNORE INTO prefix_dbpedia_resource_to_md5 SELECT object,md5(object) FROM prefix_dbpedia_properties_original;

DROP TABLE IF EXISTS `prefix_dbpedia_predicate_to_md5`;
CREATE TABLE `prefix_dbpedia_predicate_to_md5` (
  `predicate` varchar(1000) NOT NULL,
  `predicate_md5` char(32) NOT NULL,
  PRIMARY KEY `idx_predicate_to_md5_type_md5` (`predicate_md5`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO prefix_dbpedia_predicate_to_md5 SELECT predicate,md5(predicate) FROM prefix_dbpedia_properties_original;

# Compile the statistics
DROP TABLE IF EXISTS `prefix_stat_type_count`;
CREATE TABLE `prefix_stat_type_count` (
  `type` char(32) NOT NULL,
  `type_count` int(11) NOT NULL,
  KEY `idx_type_count_type` (`type`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_type_count SELECT type,COUNT(resource) FROM prefix_dbpedia_types_md5 GROUP BY (type);

DROP TABLE IF EXISTS `prefix_stat_type_apriori_probability`;
CREATE TABLE `prefix_stat_type_apriori_probability` (
  `type` char(32) NOT NULL,
  `probability` float NOT NULL,
  KEY `idx_type_apriori_probability_type` (`type`) 
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_type_apriori_probability select type,type_count/(select count(resource_md5) from prefix_dbpedia_resource_to_md5) AS rel_count from prefix_stat_type_count;

DROP TABLE IF EXISTS `prefix_stat_resource_predicate_tf`;
CREATE TABLE `prefix_stat_resource_predicate_tf` (
  `resource` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `tf` int(11) NOT NULL,
  `outin` int(11) NOT NULL,
  KEY `idx_resource_predicate_tf_resource` (`resource`),
  KEY `idx_resource_predicate_tf_predicate` (`predicate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_resource_predicate_tf SELECT subject, predicate, COUNT(object),0 FROM prefix_dbpedia_properties_md5 GROUP BY subject, predicate;
INSERT INTO prefix_stat_resource_predicate_tf SELECT object, predicate, COUNT(subject),1 FROM prefix_dbpedia_properties_md5 GROUP BY object, predicate;

DROP TABLE IF EXISTS `prefix_stat_type_predicate_percentage`;
CREATE TABLE `prefix_stat_type_predicate_percentage` (
  `type` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `outin` int(11) NOT NULL,
  `percentage` float NOT NULL,
  KEY `idx_type_predicate_percentage_type` (`type`),
  KEY `idx_type_predicate_percentage_predicate` (`predicate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_type_predicate_percentage SELECT types.type, res.predicate, 0, COUNT(subject)/(SELECT COUNT(subject) FROM prefix_dbpedia_properties_md5 AS resinner WHERE res.predicate = resinner.predicate)
FROM
prefix_dbpedia_properties_md5 AS res,
prefix_dbpedia_types_md5 AS types
WHERE
res.subject = types.resource
GROUP BY res.predicate,types.type;

INSERT INTO prefix_stat_type_predicate_percentage SELECT types.type, res.predicate, 1, COUNT(object)/(SELECT COUNT(object) FROM prefix_dbpedia_properties_md5 AS resinner WHERE res.predicate = resinner.predicate)
FROM
prefix_dbpedia_properties_md5 AS res,
prefix_dbpedia_types_md5 AS types
WHERE
res.object = types.resource
GROUP BY res.predicate,types.type;

DROP TABLE IF EXISTS `prefix_stat_predicate_weight_apriori`;
CREATE TABLE `prefix_stat_predicate_weight_apriori` (
  `predicate` char(32) NOT NULL,
  `outin` int(11) NOT NULL,
  `weight` float NOT NULL,
  KEY `idx_predicate_weight_apriori_predicate` (`predicate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_predicate_weight_apriori SELECT predicate,outin,SUM((percentage - probability)*(percentage - probability)) FROM prefix_stat_type_predicate_percentage 
LEFT JOIN prefix_stat_type_apriori_probability ON prefix_stat_type_predicate_percentage.type = prefix_stat_type_apriori_probability.type
GROUP BY predicate,outin;

# Materialize the Types
# uses one intermediate table

DROP TABLE IF EXISTS `prefix_dbpedia_untyped_instance`;
CREATE  TABLE `prefix_dbpedia_untyped_instance` (
  `resource` VARCHAR(1000) NOT NULL ,
  `resource_md5` CHAR(32) NOT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_dbpedia_untyped_instance SELECT res.resource,res.resource_md5 FROM prefix_dbpedia_resource_to_md5 AS res
LEFT JOIN prefix_dbpedia_types_md5 as typ ON res.resource_md5=typ.resource;
WHERE ISNULL(type);
*/

DROP TABLE IF EXISTS `prefix_stat_resource_predicate_type`;
CREATE TABLE `prefix_stat_resource_predicate_type` (
  `resource` char(32) NOT NULL,
  `predicate` char(32) NOT NULL,
  `type` char(32) NOT NULL,
  `tf` float NOT NULL,
  `percentage` float NOT NULL,
  `weight` float NOT NULL,
  KEY `idx_prefix_stat_resource_predicate_type` (`resource`,`type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_stat_resource_predicate_type 
SELECT instance.resource_md5,tf.predicate,perc.type,tf,percentage,weight
FROM prefix_dbpedia_resource_to_md5 as instance
LEFT JOIN prefix_stat_resource_predicate_tf as tf on instance.resource_md5 = tf.resource
LEFT JOIN prefix_stat_type_predicate_percentage as perc on tf.predicate = perc.predicate and tf.outin = perc.outin 
LEFT JOIN prefix_stat_predicate_weight_apriori as weight on tf.predicate = weight.predicate and tf.outin = weight.outin
LEFT JOIN prefix_stat_type_apriori_probability as tap on perc.type = tap.type
LEFT JOIN prefix_dbpedia_type_to_md5 as t2md5 on tap.type = t2md5.type_md5
WHERE NOT perc.type IS NULL;

DROP TABLE IF EXISTS `prefix_resulting_types`;
CREATE TABLE `prefix_resulting_types` (
  `resource` VARCHAR(1000) NOT NULL ,
  `type` VARCHAR(1000) NOT NULL ,
  `score` FLOAT NOT NULL ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_resulting_types 
SELECT resource,type,SUM(tf*percentage*weight)/SUM(tf*weight) AS score
FROM prefix_stat_resource_predicate_type 
GROUP BY resource,type 
HAVING score>=0.05;

DROP TABLE IF EXISTS `prefix_resulting_types_readable`;
CREATE TABLE `prefix_resulting_types_readable` (
  `resource` varchar(1000) NOT NULL,
  `type` varchar(1000) NOT NULL,
  `score` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_resulting_types_readable
SELECT r2md5.resource,t2md5.type, score FROM prefix_resulting_types AS res
LEFT JOIN prefix_dbpedia_resource_to_md5 AS r2md5 ON res.resource=r2md5.resource_md5
LEFT JOIN prefix_dbpedia_type_to_md5 AS t2md5 ON res.type=t2md5.type_md5;

# Filter results and write into outfile
DROP TABLE IF EXISTS `prefix_resulting_types_filtered`;
CREATE TABLE `prefix_resulting_types_filtered` (
  `resource` varchar(1000) NOT NULL,
  `type` varchar(1000) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO prefix_resulting_types_filtered 
SELECT results.resource, results.type
FROM prefix_resulting_types_readable AS results
INNER JOIN prefix_dbpedia_untyped_instance AS untyped ON results.resource = untyped.resource
WHERE score >= 0.7
GROUP BY resource, type;


SELECT concat('<', resource, '> ', '<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> ' , '<',type, '> .')
FROM `prefix_resulting_types_filtered`
INTO OUTFILE '/tmp/generated_instance_types_prefix.nt';