CREATE OR REPLACE FUNCTION public.get_sysfiles_entity(
	trackid text,
	OUT sysfileid text)
    RETURNS text
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
	DECLARE
	trackentity UUID := NULL;
	BEGIN
		SELECT recid INTO trackentity FROM rdev___sysfiles WHERE entityid = CAST(trackid AS UUID);
		sysfileid := CAST(trackentity AS UUID);
	END
$BODY$;

ALTER FUNCTION public.get_sysfiles_entity(text)
    OWNER TO postgres;
