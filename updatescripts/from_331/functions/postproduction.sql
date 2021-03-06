CREATE OR REPLACE FUNCTION postProduction(INTEGER, NUMERIC, BOOLEAN, INTEGER) RETURNS INTEGER AS $$
DECLARE
  pWoid          ALIAS FOR $1;
  pQty           ALIAS FOR $2;
  pBackflush     ALIAS FOR $3;
  pItemlocSeries ALIAS FOR $4;
  _invhistid     INTEGER;
  _itemlocSeries INTEGER;
  _parentQty     NUMERIC;
  _r             RECORD;
  _sense         TEXT;
  _wipPost       NUMERIC;
  _woNumber      TEXT;

BEGIN

  IF (pQty = 0) THEN
    RETURN 0;
  ELSIF (pQty > 0) THEN
    _sense = 'from';
  ELSE
    _sense = 'to';
  END IF;

  IF ( ( SELECT wo_status
         FROM wo
         WHERE (wo_id=pWoid) ) NOT IN  ('R','E','I') ) THEN
    RETURN -1;
  END IF;

  --If this is item type Job then we are using the wrong function
  IF (EXISTS(SELECT item_type
             FROM wo,itemsite,item
             WHERE ((wo_id=pWoid)
                AND (wo_itemsite_id=itemsite_id)
                AND (itemsite_item_id=item_id)
                AND (item_type = 'J')))) THEN
    RAISE EXCEPTION 'Work orders for job items are posted when quantities are shipped on the associated sales order';
  END IF;

  SELECT formatWoNumber(pWoid) INTO _woNumber;

  SELECT roundQty(item_fractional, pQty) INTO _parentQty
  FROM wo, itemsite, item
  WHERE ((wo_itemsite_id=itemsite_id)
   AND (itemsite_item_id=item_id)
   AND (wo_id=pWoid));

--  Create the material receipt transaction
  IF (pItemlocSeries = 0) THEN
    SELECT NEXTVAL('itemloc_series_seq') INTO _itemlocSeries;
  ELSE
    _itemlocSeries = pItemlocSeries;
  END IF;

  IF (pBackflush) THEN
    FOR _r IN SELECT womatl_id, womatl_qtyper, womatl_scrap, womatl_qtywipscrap,
		     womatl_qtyreq - roundQty(item_fractional, womatl_qtyper * wo_qtyord) AS preAlloc
	      FROM womatl, wo, itemsite, item
	      WHERE ((womatl_issuemethod IN ('L', 'M'))
		AND  (womatl_wo_id=pWoid)
		AND  (womatl_wo_id=wo_id)
		AND  (womatl_itemsite_id=itemsite_id)
		AND  (itemsite_item_id=item_id)) LOOP
      -- CASE says: don't use scrap % if someone already entered actual scrap
      SELECT issueWoMaterial(_r.womatl_id,
			     CASE WHEN _r.womatl_qtywipscrap > _r.preAlloc THEN
			       _parentQty * _r.womatl_qtyper + (_r.womatl_qtywipscrap - _r.preAlloc)
			     ELSE
			       _parentQty * _r.womatl_qtyper * (1 + _r.womatl_scrap)
			     END, _itemlocSeries) INTO _itemlocSeries;

      UPDATE womatl
      SET womatl_issuemethod='L'
      WHERE ( (womatl_issuemethod='M')
       AND (womatl_id=_r.womatl_id) );

    END LOOP;
  END IF;

  SELECT CASE
           WHEN (wo_cosmethod = 'D') THEN
             wo_wipvalue
           ELSE
             round((wo_wipvalue - (wo_postedvalue / wo_qtyord * (wo_qtyord - wo_qtyrcv - pQty))),2)
         END INTO _wipPost
  FROM wo
  WHERE (wo_id=pWoid);

  SELECT postInvTrans( itemsite_id, 'RM', _parentQty,
                       'W/O', 'WO', _woNumber, '', ('Receive Inventory ' || item_number || ' ' || _sense || ' Manufacturing'),
                       costcat_asset_accnt_id, costcat_wip_accnt_id, _itemlocSeries, CURRENT_DATE,
                       -- the following is only actually used when the item is average costed
                       _wipPost ) INTO _invhistid
  FROM wo, itemsite, item, costcat
  WHERE ( (wo_itemsite_id=itemsite_id)
   AND (itemsite_item_id=item_id)
   AND (itemsite_costcat_id=costcat_id)
   AND (wo_id=pWoid) );

--  Increase this W/O's received qty decrease its WIP value
  UPDATE wo
  SET wo_qtyrcv = (wo_qtyrcv + _parentQty),
      wo_wipvalue = (wo_wipvalue - (CASE WHEN (itemsite_costmethod='A') THEN _wipPost ELSE (stdcost(itemsite_item_id) * _parentQty)  END))
  FROM itemsite, item
  WHERE ((wo_itemsite_id=itemsite_id)
   AND (itemsite_item_id=item_id)
   AND (wo_id=pWoid));

--  Make sure the W/O is at issue status
  UPDATE wo
  SET wo_status='I'
  WHERE (wo_id=pWoid);

  RETURN _itemlocSeries;

END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN) RETURNS INTEGER AS $$
BEGIN
  RAISE NOTICE 'postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN) is deprecated. please use postProduction(INTEGER, NUMERIC, BOOLEAN, INTEGER) instead';
  RETURN postProduction($1, $2, $3, 0);
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN, INTEGER) RETURNS INTEGER AS $$
BEGIN
  RAISE NOTICE 'postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN, INTEGER) is deprecated. please use postProduction(INTEGER, NUMERIC, BOOLEAN, INTEGER) instead';
  RETURN postProduction($1, $2, $3, $5);
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN, INTEGER, TEXT, TEXT) RETURNS INTEGER AS $$
BEGIN
  RAISE NOTICE 'postProduction(INTEGER, NUMERIC, BOOLEAN, BOOLEAN, INTEGER, TEXT, TEXT) is deprecated. please use postProduction(INTEGER, NUMERIC, BOOLEAN, INTEGER) instead';
  RETURN postProduction($1, $2, $3, $5);
END;
$$ LANGUAGE 'plpgsql';
