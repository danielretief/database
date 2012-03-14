CREATE OR REPLACE FUNCTION setNextInvcNumber(INTEGER) RETURNS INTEGER  AS '
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  pNumber ALIAS FOR $1;
  _orderseqid INTEGER;

BEGIN

  SELECT orderseq_id INTO _orderseqid
  FROM orderseq
  WHERE (orderseq_name=''InvcNumber'');

  IF (NOT FOUND) THEN
    SELECT NEXTVAL(''orderseq_orderseq_id_seq'') INTO _orderseqid;

    INSERT INTO orderseq (orderseq_id, orderseq_name, orderseq_number)
    VALUES (_orderseqid, ''InvcNumber'', pNumber);

  ELSE
    UPDATE orderseq
    SET orderseq_number=pNumber
    WHERE (orderseq_name=''InvcNumber'');
  END IF;

  RETURN _orderseqid;

END;
' LANGUAGE 'plpgsql';
