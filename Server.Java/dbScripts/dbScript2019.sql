CREATE OR REPLACE FUNCTION public.getnexttrack_v2(i_deviceid uuid)
 RETURNS TABLE(track character varying, method integer, useridrecommended character varying, txtrecommendedinfo character varying, timeexecute character varying)
 LANGUAGE plpgsql
AS $function$
DECLARE
		declare t timestamptz := clock_timestamp(); -- запоминаем начальное время выполнения процедуры
		i_userid UUID; -- = i_deviceid; -- в дальнейшем заменить получением userid по deviceid
		user_name character varying;
	useridrecommended UUID;
BEGIN
	-- Добавляем устройство, если его еще не существует
	PERFORM registerdevice(i_deviceid, 'New device');


--если пользователь alexv2test то пускаем выполнение в getuserrecommended, иначе идем по старому

select userid into i_userid from devices where recid = i_deviceid; --получаем id пользователя по id_device
select recname into user_name from users where recid = i_userid; --получаем имя пользователя по его id


if user_name = 'alexv2test' then
--return QUERY select getuserrecommended(i_userid); --return getuserrecommended(i_userid)

useridrecommended = cast('11111111-0000-0888-0000-000000000000' as UUID); --выдавать от пользователя alexv

	RETURN QUERY SELECT
					 nexttrack.track,
					 nexttrack.methodid,
					 nexttrack.useridrecommended,
					 nexttrack.txtrecommendedinfo,
					 CAST((clock_timestamp() - t ) AS CHARACTER VARYING) -- возвращаем время выполнения процедуры
				 FROM getuserrecommended(i_userid, useridrecommended, i_deviceid) AS nexttrack;

return;
end if;

	-- Возвращаем trackid, конвертируя его в character varying, и methodid
	RETURN QUERY SELECT
					 CAST((nexttrack.track) AS CHARACTER VARYING),
					 nexttrack.methodid,
					 CAST((nexttrack.useridrecommended) AS CHARACTER VARYING),
					 nexttrack.txtrecommendedinfo,
					 CAST((clock_timestamp() - t ) AS CHARACTER VARYING) -- возвращаем время выполнения процедуры
				 FROM getnexttrackid_v17(i_deviceid) AS nexttrack;
END;
$function$
;



CREATE OR REPLACE FUNCTION public.getuserrecommended(i_userid uuid, i_useridrecommended uuid, i_deviceid UUID)
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
					txtrecommendinfo
				)
		
				select
					uuid_generate_v4(),
					now(),
					i_deviceid,
					cast(trackid as UUID),
					temp_track.meth,
					txtrecommeninfo
					from temp_track;
				
				return query select * from temp_track;
			
				
else -- иначе возвращаем "конечный" трэк
		return query
		select cast(end_trackid as character varying) as trackid , 
		10 as methodid ,
		cast(i_useridrecommended as character varying), 
		cast ('конец' as character varying ) as txtrecommendedinfo;
end if;

	return ;
end;
 $function$
;
