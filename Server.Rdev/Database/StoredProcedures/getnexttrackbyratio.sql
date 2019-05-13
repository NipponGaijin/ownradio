CREATE OR REPLACE FUNCTION public.getnexttrackbyratio(i_deviceid uuid, i_ratio integer)
 RETURNS TABLE(recid uuid, method integer, artist text, recname text, length integer)
 LANGUAGE plpgsql
AS $function$ 	
declare 
rnd INTEGER = (SELECT (random() * 101)::integer);
o_methodid INTEGER;
owntracks  INTEGER;
newtracks  INTEGER;
peresec INTEGER;
i_userid   UUID ;
temp_trackid uuid; 
tmp_txtrecommendinfo text;

	--id конечного трэка
		end_trackid UUID= cast('10000000-0000-0000-0000-000000000001' as UUID);
	
begin
	
--получаем id пользователя по id устройства
	 select userid into i_userid from devices where devices.recid = i_deviceid;
	
	--регистрируем устройство если его еще нет
		PERFORM registerdevice(i_deviceid, 'New device');
	
DROP TABLE IF EXISTS temp_track; 
CREATE TEMP TABLE temp_track(track uuid, methodid integer,artist text, recname text, length integer );
-- Определяем количество "своих" треков пользователя
owntracks = (SELECT COUNT(*) FROM ratings WHERE userid = i_userid AND ratingsum >= 0)+(select count(*) from tracks where tracks.deviceid in (select recid from devices where userid = i_userid));
-- Количество новых трэков пользователя
newtracks = (select count(*) from tracks where tracks.recid not in (select downloadtracks.trackid from downloadtracks where userid = i_userid) );
-- Количество пересечений с другими пользователями
peresec = (SELECT COUNT (*) FROM ratios WHERE (userid1 = i_userid OR userid2 = i_userid) AND ratio >=0);



--если пользователь новый то выдаем популярный трэк
if (  owntracks = 0 and peresec = 0) then 
		o_methodid = 8; -- метод выбора из рекомендованных треков
		SELECT o_trackid, o_textinfo INTO temp_trackid, tmp_txtrecommendinfo FROM populartracksrecommend_v1(i_userid);
		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
		IF temp_trackid IS NOT null THEN
			INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temp_trackid,
							o_methodid,
							(select concat(i_ratio,' ', CAST((tmp_txtrecommendinfo) AS CHARACTER VARYING))),
							(SELECT CAST((null) AS UUID)),
							 i_userid,
							1);
			RETURN QUERY 
				SELECT tracks.recid,
				o_methodid,
				tracks.artist,
				tracks.recname,
				tracks.length
				from tracks where tracks.recid = temp_trackid;
			RETURN;
		END IF;
end if;
					
if ( rnd < i_ratio and newtracks > 0) then 
		o_methodid = 7; -- метод выбора из рекомендованных треков
		SELECT rn_trackid, rn_txtrecommendinfo INTO temp_trackid, tmp_txtrecommendinfo FROM getrecommendedtrackid_v5(i_userid);
		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
		IF temp_trackid IS NOT null THEN
			INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temp_trackid,
							o_methodid,
							(select concat(i_ratio,' ', CAST((tmp_txtrecommendinfo) AS CHARACTER VARYING))),
							(SELECT CAST((null) AS UUID)),
							 i_userid,
							1);
			RETURN QUERY 
				SELECT tracks.recid,
				o_methodid,
				tracks.artist,
				tracks.recname,
				tracks.length
			from tracks where tracks.recid = temp_trackid;
			RETURN;
		END IF;
end if;


if (  rnd >= i_ratio and owntracks > 0) then 
o_methodid = 2; -- метод выбора из своих треков
 		INSERT INTO temp_track (
 		SELECT
 			trackid, -- выбираем id трека
 			o_methodid,
			tracks.artist,
			tracks.recname,
			tracks.length
 		FROM ratings,tracks -- из треков, имеющих рейтинг для данного пользователя
 		WHERE userid = i_userid and tracks.recid = ratings.trackid
 			  --AND lastlisten < localtimestamp - INTERVAL '1 day' -- для которого последнее прослушивание было ранее, чем за сутки до выдачи
 			  AND ratingsum >= 0 -- рейтинг трека неотрицательный
 			  AND (SELECT isexist
 				   FROM tracks
 				   WHERE tracks.recid = trackid) = 1 -- трек существует на сервере
 			  AND ((SELECT tracks.length
 					FROM tracks
 					WHERE tracks.recid = trackid) >= 120 -- продолжительность трека больше двух минут
 				   OR (SELECT tracks.length
 					   FROM tracks
 					   WHERE tracks.recid = trackid) IS NULL) -- или длина трека не известна
 			  AND ((SELECT iscensorial
 					FROM tracks
 					WHERE tracks.recid = trackid) IS NULL -- трек должен быть цензурный или непроверенный
 				   OR (SELECT iscensorial
 					   FROM tracks
 					   WHERE tracks.recid = trackid) != false)
 			  AND trackid NOT IN (SELECT trackid --не выдавать трэк если он уже когда либо выдавался
 								  FROM downloadtracks
 								  WHERE userid = i_userid)
 								 -- WHERE reccreated > localtimestamp - INTERVAL '1 week' AND deviceid = i_deviceid) -- трек недолжен быть выдан в последнюю неделю
 		--ORDER BY RANDOM()
 		LIMIT 1);

 		-- Если такой трек найден - запись информацию о нем в downloadtracks, выход из функции, возврат найденного значения
 		IF FOUND then
 		
 			INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
			VALUES (uuid_generate_v4(),
						now(),
						i_deviceid,
						(select temp_track.track from temp_track),
						o_methodid,
						i_ratio,
						null,
						 i_userid,
						1);
						
 			--INSERT INTO downloadtracks (SELECT uuid_generate_v4(),now(),null, null, i_userid, temp_track.track AS trackid, temp_track.methodid AS methodid, null, null FROM temp_track);
 			RETURN QUERY SELECT * FROM temp_track;
 			RETURN;
 		else --если выдать больше нечего то выдаем конечный трэк, записываем что его выдали и больше не выдаем а пускаем выполнение дальше по коду
 			
 			if (select count(*) from downloadtracks  WHERE deviceid = i_deviceid and trackid = end_trackid)=0 then --если конечный трэк не выдавался еще то выдаем
 				INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
				VALUES (uuid_generate_v4(),
						now(),
						i_deviceid,
						end_trackid,
						o_methodid,
						i_ratio,
						null,
						 i_userid,
						1);
						
					RETURN QUERY 
					SELECT tracks.recid,
					o_methodid,
					tracks.artist,
					tracks.recname,
					tracks.length
					from tracks where tracks.recid = end_trackid;
				RETURN;
 			end if;
 			
 		END IF;
end if;


--если ни одно из условий выше не выполнилось то выдаем случайный трэк из всех что есть на сервере
--if ( rnd >= i_ratio and owntracks = 0) or ( rnd < i_ratio and newtracks = 0 ) then 
	o_methodid = 1; -- метод выбора случайного трека
	INSERT INTO temp_track (
	SELECT
		tracks.recid,
		o_methodid,
			tracks.artist,
			tracks.recname,
			tracks.length
	FROM tracks
	WHERE isexist = 1 -- существующий на сервере 
		AND (iscorrect IS NULL OR iscorrect != false)
		  AND (iscensorial IS NULL OR iscensorial != false) -- цензурный
		  AND (tracks.length > 120 OR tracks.length IS NULL) -- продолжительностью более 2х минут.
	ORDER BY RANDOM()
	LIMIT 1);
	INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
			VALUES (uuid_generate_v4(),
						now(),
						i_deviceid,
						(select temp_track.track from temp_track),
						o_methodid,
						i_ratio,
						null,
						 i_userid,
						1);
	RETURN QUERY SELECT * FROM temp_track;
	RETURN;
	--end if;



end
 $function$
;
