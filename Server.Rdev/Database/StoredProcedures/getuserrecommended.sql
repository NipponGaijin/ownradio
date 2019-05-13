CREATE OR REPLACE FUNCTION public.getuserrecommended(i_userid uuid, i_useridrecommended uuid, i_deviceid uuid)
 RETURNS TABLE(track character varying, methodid integer, useridrecommended character varying, txtrecommendedinfo character varying)
 LANGUAGE plpgsql
AS $function$ 	

declare 
		--id конечного трэка
		end_trackid UUID= cast('10000000-0000-0000-0000-000000000001' as UUID);
	
begin

	--АВ устройства
-- 57128f7c-307c-47d1-9e6e-e5f8d40a86d6
-- ff87a125-71cd-4d4e-809d-a1216cc45bd1
	
DROP TABLE IF EXISTS temp_track; 
CREATE TEMP TABLE temp_track(trackid character varying, meth integer, useridrecommended character varying, txtrecommeninfo character varying);



--выбираем произвольный трэк из невыданных данному пользователю
	
	insert into temp_track
	select cast(tracks.recid as character varying) as trackid , 10 , i_useridrecommended, 'выдан по тестовой рекомендации'  as txtrecommendedinfo
 	 from tracks 
	where deviceid in (select recid from devices where userid = i_useridrecommended) 
						and recid<> end_trackid 
						and recid not in 
								(
									select trackid from downloadtracks where deviceid in (select recid from devices where userid = i_userid) 
								)
		order by random()
		fetch first 1 rows only;
	
	
	
	--если нашли трэк на выдачу то записываем в downloadtracks что выдали
if (select count(*) from temp_track)>0 
then 
		INSERT INTO downloadtracks 
				(
					recid,
					reccreated,
					deviceid,
					trackid,
					methodid,
					txtrecommendinfo,
					userid
				)
		
				select
					uuid_generate_v4(),
					now(),
					i_deviceid,
					cast(trackid as UUID),
					temp_track.meth,
					txtrecommeninfo,
					i_userid
					from temp_track;
				
				return query select * from temp_track;
			
				
else if(select recid from downloadtracks where deviceid = i_deviceid and trackid = end_trackid) isnull-- иначе возвращаем "конечный" трэк
then

	INSERT INTO downloadtracks 
				(
					recid,
					reccreated,
					deviceid,
					userid,
					trackid,
					methodid,
					txtrecommendinfo
				)
		
				values(
					uuid_generate_v4(),
					now(),
					i_deviceid,
					i_deviceid,
					temp_track,
					"конец");
					
		return query
		select cast(end_trackid as character varying) as trackid , 
		10 as methodid ,
		cast(i_useridrecommended as character varying), 
		cast ('конец' as character varying) as txtrecommendedinfo;
end if;
end if;
	--return query select null;
end;
 $function$
;
