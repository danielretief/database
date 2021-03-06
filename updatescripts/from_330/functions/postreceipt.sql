CREATE OR REPLACE FUNCTION postReceipt(INTEGER, INTEGER) RETURNS INTEGER AS $$
DECLARE
  precvid		ALIAS FOR $1;
  _itemlocSeries	INTEGER := COALESCE($2, 0);
  _freightAccnt		INTEGER;
  _glDate		TIMESTAMP WITH TIME ZONE;
  _o			RECORD;
  _ordertypeabbr	TEXT;
  _r			RECORD;
  _ra			RECORD;
  _recvvalue		NUMERIC := 0;
  _tmp			INTEGER;
  _toitemitemid		INTEGER;

BEGIN
  SELECT recv_id, recv_order_type, recv_orderitem_id, recv_qty,
	 round(currToBase(recv_freight_curr_id, recv_freight, recv_date::DATE),
	       2) AS recv_freight_base,
	 recv_freight, recv_freight_curr_id, recv_date, recv_gldistdate,
	 itemsite_id, itemsite_item_id, item_inv_uom_id, itemsite_costmethod,
         vend_name
	 INTO _r
  FROM recv LEFT OUTER JOIN itemsite ON (recv_itemsite_id=itemsite_id)
            LEFT OUTER JOIN item ON (itemsite_item_id=item_id)
            LEFT OUTER JOIN vendinfo ON (recv_vend_id=vend_id)
  WHERE ((recv_id=precvid)
    AND  (NOT recv_posted));

  IF (NOT FOUND) THEN
    IF (_itemlocSeries = 0) THEN
      RETURN -10;
    END IF;
    RETURN _itemlocSeries;

  ELSEIF (_r.recv_qty <= 0) THEN
    RETURN -11;

  ELSIF (_r.recv_order_type ='PO') THEN
    _ordertypeabbr := ('P/O for ' || _r.vend_name);

    SELECT pohead_number AS orderhead_number, poitem_id AS orderitem_id,
	   currToBase(pohead_curr_id, poitem_unitprice,
		    recv_date::DATE) AS item_unitprice_base,
	   poitem_invvenduomratio AS invvenduomratio,
	   pohead_orderdate AS orderdate INTO _o
    FROM recv, pohead, poitem
    WHERE ((recv_orderitem_id=poitem_id)
      AND  (poitem_pohead_id=pohead_id)
      AND  (NOT recv_posted)
      AND  (recv_id=precvid));
  ELSIF (_r.recv_order_type ='RA') THEN
    _ordertypeabbr := 'R/A';

    SELECT rahead_number AS orderhead_number, raitem_id AS orderitem_id,
	   currToBase(rahead_curr_id, raitem_unitprice,
		    recv_date::DATE) AS item_unitprice_base,
	   raitem_qty_invuomratio AS invvenduomratio,
	   rahead_authdate AS orderdate,
	   raitem_unitcost AS unitcost INTO _o
    FROM recv, rahead, raitem
    WHERE ((recv_orderitem_id=raitem_id)
      AND  (raitem_rahead_id=rahead_id)
      AND  (NOT recv_posted)
      AND  (recv_id=precvid));
  ELSIF (_r.recv_order_type ='TO') THEN
     _ordertypeabbr := 'T/O';

    SELECT tohead_number AS orderhead_number, toitem_id AS orderitem_id,
	   toitem_stdcost AS item_unitprice_base,
	   1.0 AS invvenduomratio,
	   tohead_orderdate AS orderdate
	   INTO _o
    FROM recv, tohead, toitem
    WHERE ((recv_orderitem_id=toitem_id)
      AND  (toitem_tohead_id=tohead_id)
      AND  (NOT recv_posted)
      AND  (recv_id=precvid));
  ELSE
    RETURN -13;	-- don't know how to handle this order type
  END IF;

  IF (NOT FOUND) THEN
    IF (_itemlocSeries = 0) THEN
      RETURN -10;
    END IF;
    RETURN _itemlocSeries;
  END IF;

  IF (_itemlocSeries = 0) THEN
    _itemlocSeries := NEXTVAL('itemloc_series_seq');
  ELSEIF (_itemlocSeries < 0) THEN
    RETURN _itemlocSeries;
  END IF;

  _glDate := COALESCE(_r.recv_gldistdate, _r.recv_date);

  IF (_r.itemsite_id = -1 OR _r.itemsite_id IS NULL) THEN
    IF (_r.recv_order_type != 'PO') THEN
      RETURN -14;	-- otherwise how to we get the accounts?
    END IF;

    SELECT insertGLTransaction( 'S/R', _r.recv_order_type, _o.orderhead_number,
				'Receive Non-Inventory from ' || _ordertypeabbr,
				 expcat_liability_accnt_id,
				 expcat_exp_accnt_id, -1,
				 round((_o.item_unitprice_base * _r.recv_qty),2),
				 _glDate::DATE ) INTO _tmp
    FROM poitem, expcat
    WHERE((poitem_expcat_id=expcat_id)
      AND (poitem_id=_o.orderitem_id));

    IF (_tmp < 0 AND _tmp != -3) THEN -- error but not 0-value transaction
      RETURN _tmp;
    END IF;

    SELECT insertGLTransaction( 'S/R', _r.recv_order_type, _o.orderhead_number,
				'Receive Non-Inventory Freight from ' || _ordertypeabbr,
				 expcat_liability_accnt_id,
				 expcat_freight_accnt_id, -1,
				 _r.recv_freight_base,
				 _glDate::DATE ),
	   expcat_freight_accnt_id INTO _tmp, _freightAccnt
    FROM poitem, expcat
    WHERE((poitem_expcat_id=expcat_id)
      AND (poitem_id=_o.orderitem_id));

    IF (_tmp < 0 AND _tmp != -3) THEN -- error but not 0-value transaction
      RETURN _tmp;
    END IF;

    _recvvalue := ROUND((_o.item_unitprice_base * _r.recv_qty),2);

    UPDATE poitem
    SET poitem_qty_received = (poitem_qty_received + _r.recv_qty),
	poitem_freight_received = (poitem_freight_received + _r.recv_freight_base)
    WHERE (poitem_id=_o.orderitem_id);

  ELSE	-- not ELSIF: some code is shared between diff order types
    IF (_r.recv_order_type = 'PO') THEN
      SELECT postInvTrans( itemsite_id, 'RP'::TEXT,
			   (_r.recv_qty * _o.invvenduomratio),
			   'S/R'::TEXT,
			   _r.recv_order_type::TEXT, _o.orderhead_number::TEXT,
			   ''::TEXT,
			   'Receive Inventory from ' || _ordertypeabbr,
			   costcat_asset_accnt_id, costcat_liability_accnt_id,
			   _itemlocSeries,
			   _glDate,
                           round((_o.item_unitprice_base * _r.recv_qty),2) -- always passing this in since it is ignored if it is not average costed item
			   ) INTO _tmp
      FROM itemsite, costcat
      WHERE ( (itemsite_costcat_id=costcat_id)
       AND (itemsite_id=_r.itemsite_id) );
      IF (NOT FOUND) THEN
	RAISE EXCEPTION 'Could not post inventory transaction: no cost category found for itemsite_id %',
	  _r.itemsite_id;
      ELSIF (_tmp < -1) THEN -- less than -1 because -1 means it is a none controlled item
	IF(_tmp = -3) THEN
	  RETURN -12; -- The GL trans value was 0 which means we likely do not have a std cost
	END IF;
	RETURN _tmp;
      END IF;

      SELECT insertGLTransaction( 'S/R', _r.recv_order_type, _o.orderhead_number,
				  'Receive Inventory Freight from ' || _o.orderhead_number,
				   costcat_liability_accnt_id,
				   costcat_freight_accnt_id, -1,
				   _r.recv_freight_base,
				   _glDate::DATE ),
	     costcat_freight_accnt_id INTO _tmp, _freightAccnt
      FROM itemsite, costcat
      WHERE ( (itemsite_costcat_id=costcat_id)
       AND (itemsite_id=_r.itemsite_id) );
      IF (NOT FOUND) THEN
	RAISE EXCEPTION 'Could not insert G/L transaction: no cost category found for itemsite_id %',
	  _r.itemsite_id;
      ELSIF (_tmp < 0 AND _tmp != -3) THEN -- error but not 0-value transaction
	RETURN _tmp;
      END IF;

      UPDATE poitem
      SET poitem_qty_received = (poitem_qty_received + _r.recv_qty),
	  poitem_freight_received = (poitem_freight_received + _r.recv_freight_base)
      WHERE (poitem_id=_o.orderitem_id);

    ELSIF (_r.recv_order_type = 'RA') THEN
      SELECT rahead.*, raitem.* INTO _ra
	FROM rahead, raitem
      WHERE ((rahead_id=raitem_rahead_id)
        AND  (raitem_id=_r.recv_orderitem_id));

      SELECT postInvTrans(_r.itemsite_id, 'RR',
			  (_r.recv_qty * _o.invvenduomratio),
			  'S/R',
			  _r.recv_order_type, _o.orderhead_number::TEXT,
			  _ra.rahead_number::TEXT || '-' || _ra.raitem_linenumber::TEXT,
			  'Receive Inventory from ' || _ordertypeabbr,
			  costcat_asset_accnt_id,
                          CASE WHEN(COALESCE(_ra.raitem_cos_accnt_id, -1) != -1) THEN _ra.raitem_cos_accnt_id
			       WHEN (_ra.raitem_warranty) THEN resolveCOWAccount(_r.itemsite_id,_ra.rahead_cust_id)
			       ELSE resolveCORAccount(_r.itemsite_id,_ra.rahead_cust_id)
			  END,
			  _itemlocSeries, _glDate, COALESCE(_o.unitcost,stdcost(itemsite_item_id)) * _r.recv_qty * _o.invvenduomratio) INTO _tmp
      FROM itemsite, costcat
      WHERE ( (itemsite_costcat_id=costcat_id)
       AND (itemsite_id=_r.itemsite_id) );

      IF (NOT FOUND) THEN
	RAISE EXCEPTION 'Could not post inventory transaction: no cost category found for itemsite_id %',
	  _r.itemsite_id;
      ELSIF (_tmp < -1) THEN -- less than -1 because -1 means it is a none controlled item
	IF(_tmp = -3) THEN
	  RETURN -12; -- The GL trans value was 0 which means we likely do not have a std cost
	END IF;
	RETURN _tmp;
      END IF;

      INSERT INTO rahist (rahist_itemsite_id, rahist_date,
			  rahist_descrip,
			  rahist_qty, rahist_uom_id,
			  rahist_source, rahist_source_id, rahist_rahead_id
	) VALUES (_r.itemsite_id, _glDate,
		  'Receive Inventory from ' || _ordertypeabbr,
		  _r.recv_qty * _o.invvenduomratio, _r.item_inv_uom_id,
		  'RR', _r.recv_id, _ra.rahead_id
	);

      SELECT insertGLTransaction( 'S/R', _r.recv_order_type, _o.orderhead_number,
				  'Receive Inventory Freight from ' || _o.orderhead_number,
				   costcat_liability_accnt_id,
				   costcat_freight_accnt_id, -1,
				   _r.recv_freight_base,
				   _glDate::DATE ),
	     costcat_freight_accnt_id INTO _tmp, _freightAccnt
      FROM itemsite, costcat
      WHERE ( (itemsite_costcat_id=costcat_id)
       AND (itemsite_id=_r.itemsite_id) );
      IF (_tmp < 0 AND _tmp != -3) THEN -- error but not 0-value transaction
	RETURN _tmp;
      END IF;

      INSERT INTO rahist (rahist_date, rahist_descrip,
			  rahist_source, rahist_source_id,
			  rahist_curr_id, rahist_amount,
			  rahist_rahead_id
	) VALUES (_glDate, 'Receive Inventory Freight from ' || _ordertypeabbr,
		  'RR', _r.recv_id, _r.recv_freight_curr_id, _r.recv_freight,
		  _ra.rahead_id
	);

      UPDATE raitem
      SET raitem_qtyreceived = (raitem_qtyreceived + _r.recv_qty)
      WHERE (raitem_id=_o.orderitem_id);

    ELSIF (_r.recv_order_type = 'TO' AND fetchMetricBool('MultiWhs')) THEN
      SELECT interWarehouseTransfer(toitem_item_id, tohead_trns_warehous_id,
            tohead_dest_warehous_id, _r.recv_qty, 
            'TO', tohead_number, 'Receive from Transit To Dest Warehouse', _itemlocSeries, _glDate ) INTO _tmp
      FROM tohead, toitem
      WHERE ((tohead_id=toitem_tohead_id)
        AND  (toitem_id=_r.recv_orderitem_id));     

      IF (_tmp < 0) THEN
	RETURN _tmp;
      END IF;

      SELECT insertGLTransaction( 'S/R', _r.recv_order_type, _o.orderhead_number,
				  'Receive Inventory Freight from ' || _o.orderhead_number,
				   costcat_toliability_accnt_id,
				   costcat_freight_accnt_id, -1,
				   _r.recv_freight_base,
				   _glDate::DATE ),
	     costcat_freight_accnt_id INTO _tmp, _freightAccnt
      FROM itemsite, costcat
      WHERE ( (itemsite_costcat_id=costcat_id)
       AND (itemsite_id=_r.itemsite_id) );
      IF (_tmp < 0 AND _tmp != -3) THEN -- error but not 0-value transaction
	RETURN _tmp;
      END IF;

      UPDATE toitem
      SET toitem_qty_received = (toitem_qty_received + _r.recv_qty),
	  toitem_freight_received = (toitem_freight_received +
				      currToCurr(_r.recv_freight_curr_id,
						 toitem_freight_curr_id,
						 _r.recv_freight, _glDate::DATE))
      WHERE (toitem_id=_o.orderitem_id);

    END IF;

    IF(_r.itemsite_costmethod='A') THEN
      _recvvalue := ROUND((_o.item_unitprice_base * _r.recv_qty),2);
    ELSE
      _recvvalue := ROUND(stdcost(_r.itemsite_item_id) * _r.recv_qty * _o.invvenduomratio, 2);
    END IF;
  END IF;

  UPDATE recv
  SET recv_value=_recvvalue, recv_posted=TRUE, recv_gldistdate=_glDate::DATE
  WHERE (recv_id=precvid);

  RETURN _itemlocSeries;

END;
$$ LANGUAGE 'plpgsql';
