. $(dirname $0)/config.sh
OUT=/home/cquest/public_html/insee_route500-france.xml

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<analysers timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
  <analyser timestamp=\"`date -u +%Y-%m-%dT%H:%M:%SZ`\">
    <class item=\"7170\" tag=\"highway\" id=\"2\" level=\"3\">
      <classtext lang=\"fr\" title=\"ref=* ou route potentiellement manquante à proximité\" />
      <classtext lang=\"en\" title=\"ref=* or possibly missing highway in the area\" />
    </class>
" > $OUT

psql osm -c "
with r as (select p.geom, r.num_route, r.dep, r.id_rte500, st_transform(p.geom,4326) as way from route500_pts p join route500 r on (r.id_rte500=p.id)
	where num_route !='')
	select format('<error class=\"2\" subclass=\"1\"><location lat=\"%s\" lon=\"%s\" /><text lang=\"en\" value=\"%s (id_route500: %s)\" /></error>',
		round(st_y(st_centroid(r.way))::numeric,6),
		round(st_x(st_centroid(r.way))::numeric,6),
		string_agg(distinct(regexp_replace(r.num_route,'([A-Z]*)([0-9A-Z]*$)','\1 \2')),','), string_agg(distinct(r.id_rte500),','))
	from r
	left join planet_osm_line l on (st_dwithin(l.way,r.geom,300)
	and (r.num_route=regexp_replace(regexp_replace(upper(l.ref),'[^0-9A-Z\.]*','','g'),'^M','D')
	  or r.num_route=regexp_replace(upper(l.tags->'old_ref'),'[^0-9A-Z]*','','g')
	  or r.num_route=regexp_replace(upper(l.tags->'nat_ref'),'[^0-9A-Z]*','','g'))
	and l.highway is not null and l.ref is not null)
	where l.ref is null group by r.way;
" -t >> $OUT

echo "
  </analyser>
</analysers>" >> $OUT

curl -s --request POST --form source='opendata_xref-france' --form code="$OSMOSEPASS" --form content=@$OUT http://osmose.openstreetmap.fr/control/send-update
