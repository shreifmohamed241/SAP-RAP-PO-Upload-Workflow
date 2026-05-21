REPORT zpur_create_po_from_upload.

PARAMETERS p_uuid TYPE zpur_upload_h-upload_uuid.

DATA: lt_items TYPE TABLE OF zpur_upload_i,
      ls_first TYPE zpur_upload_i,
      lt_po_items TYPE TABLE OF bapimepoitem,
      lt_po_itemx TYPE TABLE OF bapimepoitemx,
      lt_sch TYPE TABLE OF bapimeposchedule,
      lt_schx TYPE TABLE OF bapimeposchedulx,
      lt_return TYPE TABLE OF bapiret2,
      lv_po TYPE bapimepoheader-po_number,
      lv_matnr TYPE matnr,
      lv_lifnr TYPE lifnr.

SELECT *
  FROM zpur_upload_i
  INTO TABLE @lt_items
  WHERE upload_uuid = @p_uuid.

IF lt_items IS INITIAL.
  WRITE: / 'No items found'.
  EXIT.
ENDIF.

READ TABLE lt_items INTO ls_first INDEX 1.

CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
  EXPORTING input = ls_first-vendor
  IMPORTING output = lv_lifnr.

DATA(ls_header) = VALUE bapimepoheader(
  comp_code = '1000'
  doc_type  = 'ZNB1'
  vendor    = lv_lifnr
  purch_org = '1100'
  pur_group = '001'
  doc_date  = sy-datum ).

DATA(ls_headerx) = VALUE bapimepoheaderx(
  comp_code = 'X'
  doc_type  = 'X'
  vendor    = 'X'
  purch_org = 'X'
  pur_group = 'X'
  doc_date  = 'X' ).

LOOP AT lt_items INTO DATA(ls_item).

  CLEAR lv_matnr.

  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING input = ls_item-material
    IMPORTING output = lv_matnr.

  APPEND VALUE bapimepoitem(
    po_item    = ls_item-item_no
    material   = lv_matnr
    short_text = ls_item-short_text
    plant      = ls_item-plant
    stge_loc   = ls_item-storage_loc
    quantity   = ls_item-quantity
    po_unit    = ls_item-unit
    net_price  = ls_item-price
    price_unit = 1
    item_cat   = '0' ) TO lt_po_items.

  APPEND VALUE bapimepoitemx(
    po_item    = ls_item-item_no
    po_itemx   = 'X'
    material   = 'X'
    short_text = 'X'
    plant      = 'X'
    stge_loc   = 'X'
    quantity   = 'X'
    po_unit    = 'X'
    net_price  = 'X'
    price_unit = 'X'
    item_cat   = 'X' ) TO lt_po_itemx.

  APPEND VALUE bapimeposchedule(
    po_item       = ls_item-item_no
    sched_line    = '0001'
    delivery_date = ls_item-delivery_date
    quantity      = ls_item-quantity ) TO lt_sch.

  APPEND VALUE bapimeposchedulx(
    po_item       = ls_item-item_no
    sched_line    = '0001'
    po_itemx      = 'X'
    sched_linex   = 'X'
    delivery_date = 'X'
    quantity      = 'X' ) TO lt_schx.

ENDLOOP.

CALL FUNCTION 'BAPI_PO_CREATE1'
  EXPORTING
    poheader         = ls_header
    poheaderx        = ls_headerx
  IMPORTING
    exppurchaseorder = lv_po
  TABLES
    return           = lt_return
    poitem           = lt_po_items
    poitemx          = lt_po_itemx
    poschedule       = lt_sch
    poschedulex      = lt_schx.

LOOP AT lt_return INTO DATA(ls_ret).
  WRITE: / ls_ret-type, ls_ret-id, ls_ret-number, ls_ret-message.
ENDLOOP.

IF lv_po IS NOT INITIAL
AND NOT line_exists( lt_return[ type = 'E' ] )
AND NOT line_exists( lt_return[ type = 'A' ] )
AND NOT line_exists( lt_return[ type = 'X' ] ).

  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING wait = 'X'.

  UPDATE zpur_upload_h
    SET status = 'P',
        po_number = @lv_po
    WHERE upload_uuid = @p_uuid.

    LOOP AT lt_items INTO ls_item.

  UPDATE zpur_upload_i
    SET item_status = 'P',
        po_item_no  = @ls_item-item_no
    WHERE upload_uuid = @p_uuid
      AND item_no     = @ls_item-item_no.

ENDLOOP.

  COMMIT WORK.

  WRITE: / 'PO Created:', lv_po.

ELSE.

  CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

  WRITE: / 'PO not created'.

ENDIF.
