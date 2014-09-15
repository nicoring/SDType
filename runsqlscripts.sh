
for languageprefix in 'en_' 'ca_' 'de_' 'es_' 'eu_' 'fr_' 'id_' 'it_' 'ja_' 'ko_' 'nl_' 'pl_' 'pt_' 'ru_' 'tr_'
do
	cat generate_types_all.sql | sed "s/prefix_/$languageprefix/g" | mysql -u dstype -pdstype dstype &	

done
