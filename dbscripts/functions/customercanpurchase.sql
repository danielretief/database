CREATE OR REPLACE FUNCTION customerCanPurchase(INTEGER, INTEGER) RETURNS BOOL AS $$
DECLARE
  pitemid ALIAS FOR $1;
  pCustid ALIAS FOR $2;

BEGIN
  RETURN customerCanPurchase(pitemid, pCustid, -1);
END;
$$ LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION customerCanPurchase(INTEGER, INTEGER, INTEGER) RETURNS BOOL AS $$
DECLARE
  pitemid ALIAS FOR $1;
  pCustid ALIAS FOR $2;
  pShiptoid AlIAS FOR $3;
  _id INTEGER;
  _item RECORD;

BEGIN

  SELECT item_sold, item_exclusive
    INTO _item
    FROM item
   WHERE(item_id=pItemid);

--  Make sure that this is at least a sold Item
  IF (NOT _item.item_sold) THEN
    RETURN FALSE;
  END IF;

--  Everyone can purchase a non-exclusive item
  IF (NOT _item.item_exclusive) THEN
    RETURN TRUE;
  END IF;

  IF(pShiptoid != -1) THEN
--  Check for a shipto Assigned Price
    SELECT ipsitem_id INTO _id
      FROM ipsitem, ipshead, ipsass
     WHERE((ipsitem_ipshead_id=ipshead_id)
       AND (ipsass_ipshead_id=ipshead_id)
       AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
       AND (ipsitem_item_id=pItemid)
       AND (ipsass_shipto_id != -1)
       AND (ipsass_shipto_id=pShiptoid))
     LIMIT 1;
    IF (FOUND) THEN
      RETURN TRUE;
    END IF;
    SELECT ipsprodcat_id INTO _id
      FROM ipsprodcat, item, ipshead, ipsass
     WHERE((ipsprodcat_ipshead_id=ipshead_id)
       AND (ipsprodcat_prodcat_id = item_prodcat_id)
       AND (ipsass_ipshead_id=ipshead_id)
       AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
       AND (item_id=pItemid)
       AND (ipsass_shipto_id != -1)
       AND (ipsass_shipto_id=pShiptoid))
     LIMIT 1;
    IF (FOUND) THEN
      RETURN TRUE;
    END IF;

--  Check for a Shipto Pattern Assigned Price
    SELECT ipsitem_id INTO _id
      FROM ipsitem, ipshead, ipsass, shipto
     WHERE((ipsitem_ipshead_id=ipshead_id)
       AND (ipsass_ipshead_id=ipshead_id)
       AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
       AND (COALESCE(length(ipsass_shipto_pattern), 0) > 0)
       AND (shipto_num ~ ipsass_shipto_pattern)
       AND (ipsass_cust_id=pCustid)
       AND (ipsitem_item_id=pItemid)
       AND (shipto_id=pShiptoid))
     LIMIT 1;
    IF (FOUND) THEN
      RETURN TRUE;
    END IF;
    SELECT ipsprodcat_id INTO _id
      FROM ipsprodcat, item, ipshead, ipsass, shipto
     WHERE((ipsprodcat_ipshead_id=ipshead_id)
       AND (ipsprodcat_prodcat_id = item_prodcat_id)
       AND (ipsass_ipshead_id=ipshead_id)
       AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
       AND (COALESCE(length(ipsass_shipto_pattern), 0) > 0)
       AND (shipto_num ~ ipsass_shipto_pattern)
       AND (ipsass_cust_id=pCustid)
       AND (item_id=pItemid)
       AND (shipto_id=pShiptoid))
     LIMIT 1;
    IF (FOUND) THEN
      RETURN TRUE;
    END IF;
  END IF;

--  Check for a Customer Assigned Price
  SELECT ipsitem_id INTO _id
    FROM ipsitem, ipshead, ipsass
   WHERE((ipsitem_ipshead_id=ipshead_id)
     AND (ipsass_ipshead_id=ipshead_id)
     AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND (ipsitem_item_id=pItemid)
     AND (COALESCE(length(ipsass_shipto_pattern), 0) = 0)
     AND (ipsass_cust_id=pCustid))
   LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;
  SELECT ipsprodcat_id INTO _id
    FROM ipsprodcat, item, ipshead, ipsass
   WHERE((ipsprodcat_ipshead_id=ipshead_id)
     AND (ipsprodcat_prodcat_id = item_prodcat_id)
     AND (ipsass_ipshead_id=ipshead_id)
     AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND (item_id=pItemid)
     AND (COALESCE(length(ipsass_shipto_pattern), 0) = 0)
     AND (ipsass_cust_id=pCustid))
   LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;

--  Check for a Customer Type Assigned Price
  SELECT ipsitem_id INTO _id
    FROM ipsitem, ipshead, ipsass, cust
   WHERE( (ipsitem_ipshead_id=ipshead_id)
     AND  (ipsass_ipshead_id=ipshead_id)
     AND  (ipsass_custtype_id != -1)
     AND  (cust_custtype_id = ipsass_custtype_id)
     AND  (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND  (ipsitem_item_id=pItemid)
     AND  (cust_id=pCustid))
    LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;
  SELECT ipsprodcat_id INTO _id
    FROM ipsprodcat, item, ipshead, ipsass, cust
   WHERE( (ipsprodcat_ipshead_id=ipshead_id)
     AND  (ipsprodcat_prodcat_id = item_prodcat_id)
     AND  (ipsass_ipshead_id=ipshead_id)
     AND  (ipsass_custtype_id != -1)
     AND  (cust_custtype_id = ipsass_custtype_id)
     AND  (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND  (item_id=pItemid)
     AND  (cust_id=pCustid))
    LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;

--  Check for a Customer Type Pattern Assigned Price
  SELECT ipsitem_id INTO _id
    FROM ipsitem, ipshead, ipsass, custtype, cust
   WHERE((ipsitem_ipshead_id=ipshead_id)
     AND (ipsass_ipshead_id=ipshead_id)
     AND (coalesce(length(ipsass_custtype_pattern), 0) > 0)
     AND (custtype_code ~ ipsass_custtype_pattern)
     AND (cust_custtype_id=custtype_id)
     AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND (ipsitem_item_id=pItemid)
     AND (cust_id=pCustid))
   LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;
  SELECT ipsprodcat_id INTO _id
    FROM ipsprodcat, item, ipshead, ipsass, custtype, cust
   WHERE((ipsprodcat_ipshead_id=ipshead_id)
     AND (ipsprodcat_prodcat_id = item_prodcat_id)
     AND (ipsass_ipshead_id=ipshead_id)
     AND (coalesce(length(ipsass_custtype_pattern), 0) > 0)
     AND (custtype_code ~ ipsass_custtype_pattern)
     AND (cust_custtype_id=custtype_id)
     AND (CURRENT_DATE BETWEEN ipshead_effective AND (ipshead_expires - 1))
     AND (item_id=pItemid)
     AND (cust_id=pCustid))
   LIMIT 1;
  IF (FOUND) THEN
    RETURN TRUE;
  END IF;

--  That's it, Sales don't count - yet
  RETURN FALSE;

END;
$$ LANGUAGE 'plpgsql';
