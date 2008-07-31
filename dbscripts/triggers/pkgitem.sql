SELECT dropIfExists('TRIGGER', 'pkgitembeforetrigger');
CREATE OR REPLACE FUNCTION _pkgitembeforetrigger() RETURNS "trigger" AS '
  DECLARE
    _object     TEXT;
    _schema     TEXT;
  BEGIN
    IF (TG_OP = ''INSERT'' OR TG_OP = ''UPDATE'') THEN
      IF (NEW.pkgitem_type = ''C'') THEN
        IF (NOT EXISTS(SELECT script_id
                       FROM script
                       WHERE ((script_id=NEW.pkgitem_item_id)
                          AND (script_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create Script % as a Package Item without a corresponding script record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''D'') THEN
        IF (NOT EXISTS(SELECT cmd_id
                       FROM cmd
                       WHERE ((cmd_id=NEW.pkgitem_item_id)
                          AND (cmd_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create Custom Command % as a Package Item without a corresponding cmd record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''F'') THEN
        RAISE EXCEPTION ''Functions are not yet supported pkgitems.'';
      ELSIF (NEW.pkgitem_type = ''G'') THEN
        RAISE EXCEPTION ''Triggers are not yet supported pkgitems.'';
      ELSIF (NEW.pkgitem_type = ''I'') THEN
        IF (NOT EXISTS(SELECT image_id
                       FROM image
                       WHERE ((image_id=NEW.pkgitem_item_id)
                          AND (image_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create Image % as a Package Item without a corresponding image record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''M'') THEN
        RAISE EXCEPTION ''Menus are not yet supported pkgitems.'';
      ELSIF (NEW.pkgitem_type = ''P'') THEN
        IF (NOT EXISTS(SELECT priv_id
                       FROM priv
                       WHERE ((priv_id=NEW.pkgitem_item_id)
                          AND (priv_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create Privilege % as a Package Item without a corresponding priv record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''R'') THEN
        IF (NOT EXISTS(SELECT report_id
                       FROM report
                       WHERE ((report_id=NEW.pkgitem_item_id)
                          AND (report_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create Report % as a Package Item without a corresponding report record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''S'') THEN
        IF (NOT EXISTS(SELECT oid
                       FROM pg_namespace
                       WHERE (nspname=NEW.pkgitem_name))) THEN
          RAISE EXCEPTION ''Cannot create Schema % as a Package Item without a corresponding schema in the database.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''T'') THEN
        IF (POSITION(''.'' IN NEW.pkgitem_name) > 0) THEN
          _schema = SPLIT_PART(NEW.pkgitem_name, ''.'', 1);
          _object = SPLIT_PART(NEW.pkgitem_name, ''.'', 2);
        ELSE
          _schema = ''public'';
          _object = NEW.pgitem_name;
        END IF;
        IF (NOT EXISTS(SELECT pg_class.oid
                     FROM pg_class, pg_namespace
                     WHERE ((relname=_object)
                        AND (relnamespace=pg_namespace.oid)
                        AND (nspname=_schema)))) THEN
          RAISE EXCEPTION ''Cannot create Table % as a Package Item without a corresponding table in the database.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''U'') THEN
        IF (NOT EXISTS(SELECT uiform_id
                       FROM uiform
                       WHERE ((uiform_id=NEW.pkgitem_item_id)
                          AND (uiform_name=NEW.pkgitem_name)))) THEN
          RAISE EXCEPTION ''Cannot create User Interface Form % as a Package Item without a corresponding uiform record.'',
            NEW.pkgitem_name;
        END IF;
      ELSIF (NEW.pkgitem_type = ''V'') THEN
        RAISE EXCEPTION ''Views are not yet supported pkgitems.'';
      ELSE
        RAISE EXCEPTION ''"%" is not a valid type of package item.'',
          NEW.pkgitem_type;
      END IF;

    ELSIF (TG_OP = ''DELETE'') THEN
      RAISE NOTICE ''Deleting % % %'', OLD.pkgitem_item_id, OLD.pkgitem_name, OLD.pkgitem_type;
      IF (OLD.pkgitem_type = ''C'') THEN
        DELETE FROM script WHERE ((script_id=OLD.pkgitem_item_id)
                              AND (script_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''D'') THEN
        DELETE FROM cmd
          WHERE ((cmd_id=OLD.pkgitem_item_id)
            AND  (cmd_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''F'') THEN
        RAISE EXCEPTION ''Functions are not yet supported pkgitems.'';
      ELSIF (OLD.pkgitem_type = ''G'') THEN
        RAISE EXCEPTION ''Triggers are not yet supported pkgitems.'';
      ELSIF (OLD.pkgitem_type = ''I'') THEN
        DELETE FROM image WHERE ((image_id=OLD.pkgitem_item_id)
                             AND (image_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''M'') THEN
        RAISE EXCEPTION ''Menus are not yet supported pkgitems.'';
      ELSIF (OLD.pkgitem_type = ''P'') THEN
        DELETE FROM priv WHERE ((priv_id=OLD.pkgitem_item_id)
                            AND (priv_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''R'') THEN
        DELETE FROM report
        WHERE ((report_id=OLD.pkgitem_item_id)
           AND (report_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''S'') THEN
        PERFORM dropIfExists(''SCHEMA'', OLD.pkgitem_name, OLD.pkgitem_name);
      ELSIF (OLD.pkgitem_type = ''T'') THEN
        IF (POSITION(''.'' IN OLD.pkgitem_name) > 0) THEN
          _schema = SPLIT_PART(OLD.pkgitem_name, ''.'', 1);
          _object = SPLIT_PART(OLD.pkgitem_name, ''.'', 2);
        ELSE
          _schema = ''public'';
          _object = OLD.pgitem_name;
        END IF;
        PERFORM dropIfExists(''TABLE'', _object, _schema);
      ELSIF (OLD.pkgitem_type = ''U'') THEN
        DELETE FROM uiform
        WHERE ((uiform_id=OLD.pkgitem_item_id)
           AND (uiform_name=OLD.pkgitem_name));
      ELSIF (OLD.pkgitem_type = ''V'') THEN
        RAISE EXCEPTION ''Views are not yet supported pkgitems.'';
      ELSE
        RAISE EXCEPTION ''"%" is not a valid type of package item.'',
          OLD.pkgitem_type;
      END IF;
      RETURN OLD;
    END IF;

    RETURN NEW;
  END;
' LANGUAGE 'plpgsql';

CREATE TRIGGER pkgitembeforetrigger
  BEFORE  INSERT OR
	  UPDATE OR DELETE
  ON pkgitem
  FOR EACH ROW
  EXECUTE PROCEDURE _pkgitembeforetrigger();
