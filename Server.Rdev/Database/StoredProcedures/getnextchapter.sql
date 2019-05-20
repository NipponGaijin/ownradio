CREATE OR REPLACE FUNCTION public.getnextchapter(i_deviceid uuid, i_bookid uuid, i_chapter integer)
 RETURNS TABLE(recid uuid)
 LANGUAGE plpgsql
AS $function$ 	
declare 
	temptrackid uuid;
tmpmaxchapter int;
tmpnextchapter int;
i_userid   UUID;
begin
	
	--получаем id пользователя по id устройства
	 select userid into i_userid from devices where devices.recid = i_deviceid;
	
--Если не передан bookid книги, выдать случайную первую главу случайной книги, ранее не выданной. Сохранить информацию о выдаче в downloadtracks.
if (i_bookid is null ) then

	--ищем главу по условиям выше, пишем её recid в temptrackid
	select tracks.recid into temptrackid from tracks
	where tracks.mediatype = 'audiobook'
	and tracks.chapter = 1 
	and tracks.recid not in (select downloadtracks.trackid from downloadtracks where downloadtracks.userid = i_userid) --не выдавалась ранее
	order by random()
	limit 1;

	--если такая глава найдена
	if temptrackid is not null then
		
		--сохраняем эту главу что она выдана
		INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temptrackid,
							null,
							null,
							(SELECT CAST((null) AS UUID)),
							 i_userid,
							1);
						
		--возвращаем эту главу
		return query 
		select temptrackid;
		return;
	else 
		return; -- если запись не найдена
	end if;

end if;


--Если передан bookid и номер главы - выдать запрошенную главу, если она имеется. Сохранить информацию о выдаче в downloadtracks.
if (i_bookid is not null and i_chapter is not null) then

	--ищем главу по условиям выше, пишем её recid в temptrackid
	select tracks.recid into temptrackid from tracks
	where tracks.mediatype = 'audiobook'
	and tracks.chapter = i_chapter 
	and tracks.ownerrecid = i_bookid;

	--если такая глава найдена
	if temptrackid is not null then
		
		--сохраняем эту главу что она выдана
		INSERT INTO downloadtracks (recid, reccreated,deviceid, trackid, methodid, txtrecommendinfo, userrecommend, userid,recstate)
				VALUES (uuid_generate_v4(),
							now(),
							i_deviceid,
							temptrackid,
							null,
							null,
							(SELECT CAST((null) AS UUID)),
							 i_userid,
							1);
						
		--возвращаем эту главу
		return query 
		select temptrackid;
		return;
	else
		return; --если запись не найдена выходим
	end if;
	
end if;




--Если передан bookid без номера главы, выдать следующую, после последней выданной главы, если есть.
if (i_bookid is not null and i_chapter is null) then
	
	select max(tracks.chapter) into tmpmaxchapter from tracks --максимальная глава выданная этому пользователю по книге
		left join downloadtracks on tracks.recid = downloadtracks.trackid
		where tracks.ownerrecid = i_bookid
			and downloadtracks.userid = i_userid;
		
	if (tmpmaxchapter is null) then 
		tmpnextchapter = (select min(tracks.chapter) from tracks where ownerrecid = i_bookid);	--если ни одна глава не выдавалась пользователю то берем наименьшую существующую главу
		else
		tmpnextchapter = tmpmaxchapter + 1; --иначе прибавляем 1 к ранее выданной главе
	end if;

	return query
	select * from getnextchapter(i_deviceid, i_bookid, tmpnextchapter); --теперь когда глава известна вызываем эту же функцию т.к для такой ситуации есть функционал выше
	return;

	
end if;
	
end
 $function$
;
