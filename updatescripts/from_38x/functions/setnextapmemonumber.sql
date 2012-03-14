CREATE OR REPLACE FUNCTION setNextAPMemoNumber(INTEGER) RETURNS INTEGER AS '
-- Copyright (c) 1999-2012 by OpenMFG LLC, d/b/a xTuple. 
-- See www.xtuple.com/CPAL for the full text of the software license.
DECLARE
  pNumber ALIAS FOR $1;
  _orderseqid INTEGER;

BEGIN

  SELECT orderseq_id INTO _orderseqid
  FROM orderseq
  WHERE (orderseq_name=''APMemoNumber'');
  IF (FOUND) THEN
    UPDATE orderseq
    SET orderseq_number=pNumber
    WHERE (orderseq_id=_orderseqid);

  ELSE
    INSERT INTO orderseq
    (orderseq_name, orderseq_number)
    VALUES
    (''APMemoNumber'', pNumber);
  END IF;

  RETURN 1;

END;
' LANGUAGE 'plpgsql';
