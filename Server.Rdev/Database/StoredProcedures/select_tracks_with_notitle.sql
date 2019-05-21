CREATE OR REPLACE FUNCTION public.select_tracks_with_notittle(
	)
    RETURNS TABLE(recid uuid, recname text, reccode text, recdescription text, reccreated timestamp without time zone, recupdated timestamp without time zone, reccreatedby text, recupdatedby text, recstate integer, artist text, localdevicepathupload text, path text, deviceid uuid, uploaduserid uuid, iscensorial boolean, iscorrect boolean, isfilledinfo boolean, length integer, size integer, chapter integer, mediatype text, ownerrecid text, outerguid uuid, outersource text) 
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$ 	
	begin
return QUERY
SELECT tracks.recid,tracks.recname , tracks.reccode, tracks.recdescription, tracks.reccreated, tracks.recupdated, tracks.reccreatedby, tracks.recupdatedby, tracks.recstate, tracks.artist, tracks.localdevicepathupload, tracks.path, tracks.deviceid, tracks.uploaduserid, tracks.iscensorial, tracks.iscorrect, tracks.isfilledinfo, tracks.length, tracks.size, tracks.chapter, tracks.mediatype, tracks.ownerrecid, tracks.outerguid, tracks.outersource 
FROM tracks
where 
(tracks.isexist = 1) 
AND
(tracks.isfilledinfo is null
or tracks.recname = '' 
or tracks.artist = '' 
-- or tracks.recname = 'Title'
-- or tracks.artist = 'Artist'
or tracks.recname is null
or tracks.artist is null
and tracks.recid in (select entityid from rdev___sysfiles where length(body)>500)
)
order by tracks.reccreated desc
limit 1;
	end
 $BODY$;

ALTER FUNCTION public.select_tracks_with_notittle()
    OWNER TO postgres;
