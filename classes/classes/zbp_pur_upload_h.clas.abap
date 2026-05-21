CLASS lhc_Header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Header RESULT result.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~setInitialStatus.

    METHODS setUploadedBy FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~setUploadedBy.

    METHODS setUploadNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Header~setUploadNumber.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION Header~approve RESULT result.

    METHODS createPO FOR MODIFY
      IMPORTING keys FOR ACTION Header~createPO RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION Header~reject RESULT result.

    METHODS submitForApproval FOR MODIFY
      IMPORTING keys FOR ACTION Header~submitForApproval RESULT result.

    METHODS uploadExcel FOR MODIFY
      IMPORTING keys FOR ACTION Header~uploadExcel RESULT result.
    METHODS processUploadedFile FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Header~processUploadedFile.

      METHODS send_approval_email
        IMPORTING
        iv_upload_uuid TYPE zpur_upload_h-upload_uuid
        iv_upload_no   TYPE zpur_upload_h-upload_no.

        METHODS get_instance_features FOR INSTANCE FEATURES
  IMPORTING keys REQUEST requested_features FOR Header RESULT result.

ENDCLASS.

CLASS lhc_Header IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD setInitialStatus.
    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( Status )
      WITH VALUE #( FOR ls_key_status IN keys
                    ( %tky = ls_key_status-%tky
                      Status = 'D' ) ).
  ENDMETHOD.

  METHOD setUploadedBy.
    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( UploadedBy UploadDate UploadTime )
      WITH VALUE #( FOR ls_key_user IN keys
                    ( %tky       = ls_key_user-%tky
                      UploadedBy = sy-uname
                      UploadDate = sy-datum
                      UploadTime = sy-uzeit ) ).
  ENDMETHOD.

  METHOD setUploadNumber.
    SELECT SINGLE last_no
      FROM zpur_upload_no
      INTO @DATA(lv_last_no).

    IF sy-subrc <> 0.
      lv_last_no = 0.
    ENDIF.

    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( UploadNo )
      WITH VALUE #( FOR ls_key_no IN keys INDEX INTO lv_idx
                    ( %tky     = ls_key_no-%tky
                      UploadNo = lv_last_no + lv_idx ) ).

    MODIFY zpur_upload_no FROM @( VALUE #(
      client  = sy-mandt
      last_no = lv_last_no + lines( keys ) ) ).
  ENDMETHOD.

  METHOD submitForApproval.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers_submit).

  LOOP AT lt_headers_submit INTO DATA(ls_header_submit).

    "Status validation
    IF ls_header_submit-Status <> 'D'.

      APPEND VALUE #(
        %tky = ls_header_submit-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Only Draft documents can be submitted.' )
      ) TO reported-header.

      RETURN.

    ENDIF.

    "Read uploaded items
    SELECT *
      FROM zpur_upload_i
      INTO TABLE @DATA(lt_items)
      WHERE upload_uuid = @ls_header_submit-UploadUuid.

    "No items validation
    IF lt_items IS INITIAL.

      APPEND VALUE #(
        %tky = ls_header_submit-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Cannot submit. No items uploaded.' )
      ) TO reported-header.

      RETURN.

    ENDIF.

    "Item validations
    LOOP AT lt_items INTO DATA(ls_item).

      IF ls_item-material IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header_submit-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Material missing in item { ls_item-item_no }| )
        ) TO reported-header.

        RETURN.

      ENDIF.

      IF ls_item-quantity IS INITIAL
         OR ls_item-quantity <= 0.

        APPEND VALUE #(
          %tky = ls_header_submit-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Invalid quantity in item { ls_item-item_no }| )
        ) TO reported-header.

        RETURN.

      ENDIF.

      IF ls_item-unit IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header_submit-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Unit missing in item { ls_item-item_no }| )
        ) TO reported-header.

        RETURN.

      ENDIF.

      IF ls_item-plant IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header_submit-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Plant missing in item { ls_item-item_no }| )
        ) TO reported-header.

        RETURN.

      ENDIF.

      IF ls_item-delivery_date IS INITIAL.

        APPEND VALUE #(
          %tky = ls_header_submit-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = |Delivery date missing in item { ls_item-item_no }| )
        ) TO reported-header.

        RETURN.

      ENDIF.

    ENDLOOP.

    "Change status to Submitted
    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( Status )
      WITH VALUE #( ( %tky   = ls_header_submit-%tky
                      Status = 'S' ) ).

    "Send approval email
    send_approval_email(
      iv_upload_uuid = ls_header_submit-UploadUuid
      iv_upload_no   = ls_header_submit-UploadNo ).

    APPEND VALUE #(
      %tky = ls_header_submit-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = 'Upload submitted successfully. Approval email sent to manager.' )
    ) TO reported-header.

  ENDLOOP.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls_result IN lt_result
    ( %tky   = ls_result-%tky
      %param = ls_result )
  ).

ENDMETHOD.

  METHOD approve.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers_approve).

  LOOP AT lt_headers_approve INTO DATA(ls_header_approve).

    IF ls_header_approve-Status <> 'S'.

      APPEND VALUE #(
        %tky = ls_header_approve-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Only Submitted documents can be approved.' )
      ) TO reported-header.

      RETURN.

    ENDIF.

    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( Status )
      WITH VALUE #( ( %tky   = ls_header_approve-%tky
                      Status = 'A' ) ).

    APPEND VALUE #(
      %tky = ls_header_approve-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = 'Upload approved successfully. You can now create the PO.' )
    ) TO reported-header.

  ENDLOOP.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls_result IN lt_result
    ( %tky   = ls_result-%tky
      %param = ls_result )
  ).

ENDMETHOD.

  METHOD reject.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers_reject).

  LOOP AT lt_headers_reject INTO DATA(ls_header_reject).

    IF ls_header_reject-Status <> 'S'.

      APPEND VALUE #(
        %tky = ls_header_reject-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Only Submitted documents can be rejected.' )
      ) TO reported-header.

      RETURN.

    ENDIF.

    IF ls_header_reject-PoNumber IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header_reject-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = |Cannot reject. PO already created: { ls_header_reject-PoNumber }| )
      ) TO reported-header.

      RETURN.

    ENDIF.

    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( Status RejectReason )
      WITH VALUE #( ( %tky         = ls_header_reject-%tky
                      Status       = 'R'
                      RejectReason = keys[ 1 ]-%param-reject_reason ) ).

    APPEND VALUE #(
      %tky = ls_header_reject-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = 'Upload rejected successfully.' )
    ) TO reported-header.

  ENDLOOP.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls_result IN lt_result
    ( %tky   = ls_result-%tky
      %param = ls_result )
  ).

ENDMETHOD.

  METHOD uploadExcel.

    LOOP AT keys INTO DATA(ls_key_upload).

      IF ls_key_upload-UploadUuid IS INITIAL.
        APPEND VALUE #(
          %tky = ls_key_upload-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'Save the header first, then upload Excel.' )
        ) TO reported-header.
        CONTINUE.
      ENDIF.

      IF ls_key_upload-%param-file_content IS INITIAL.
        APPEND VALUE #(
          %tky = ls_key_upload-%tky
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error
            text     = 'File is empty.' )
        ) TO reported-header.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
        ENTITY Header
        UPDATE FIELDS ( FileName )
        WITH VALUE #( ( %tky     = ls_key_upload-%tky
                        FileName = ls_key_upload-%param-file_name ) ).

      DELETE FROM zpur_upload_i
        WHERE upload_uuid = @ls_key_upload-UploadUuid.

      DATA(lo_document) = xco_cp_xlsx=>document->for_file_content( ls_key_upload-%param-file_content ).
      DATA(lo_read)     = lo_document->read_access( ).
      DATA(lo_workbook) = lo_read->get_workbook( ).
      DATA(lo_sheet)    = lo_workbook->worksheet->at_position( 1 ).

      DATA lt_items TYPE TABLE OF zpur_upload_i.
      DATA lv_row TYPE i VALUE 2.
      DATA lv_item_no TYPE zpur_upload_i-item_no VALUE '00010'.

      DATA: lv_vendor_str        TYPE string,
            lv_material_str      TYPE string,
            lv_short_text_str    TYPE string,
            lv_quantity_str      TYPE string,
            lv_unit_str          TYPE string,
            lv_price_str         TYPE string,
            lv_currency_str      TYPE string,
            lv_delivery_date_str TYPE string,
            lv_plant_str         TYPE string,
            lv_storage_loc_str   TYPE string.

      DO.
        CLEAR: lv_vendor_str, lv_material_str, lv_short_text_str,
               lv_quantity_str, lv_unit_str, lv_price_str,
               lv_currency_str, lv_delivery_date_str,
               lv_plant_str, lv_storage_loc_str.

        TRY.
            lo_sheet->cursor(
              io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value(
            )->set_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_vendor_str ) ).
          CATCH cx_sy_ref_is_initial.
            EXIT.
        ENDTRY.

        IF lv_vendor_str IS INITIAL.
          EXIT.
        ENDIF.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'B' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_material_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'C' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_short_text_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'D' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_quantity_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_unit_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_price_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'G' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_currency_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'H' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_delivery_date_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'I' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_plant_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'J' )
                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
            )->get_cell( )->get_value( )->set_transformation(
              xco_cp_xlsx_read_access=>value_transformation->string_value
            )->write_to( REF #( lv_storage_loc_str ) ).
          CATCH cx_sy_ref_is_initial.
        ENDTRY.

        TRY.
            APPEND VALUE zpur_upload_i(
              client        = sy-mandt
              upload_uuid   = ls_key_upload-UploadUuid
              item_no       = lv_item_no
              vendor        = CONV #( lv_vendor_str )
              material      = CONV #( lv_material_str )
              short_text    = CONV #( lv_short_text_str )
              quantity      = CONV #( lv_quantity_str )
              unit          = CONV #( lv_unit_str )
              price         = CONV #( lv_price_str )
              currency      = CONV #( lv_currency_str )
              delivery_date = CONV #( lv_delivery_date_str )
              plant         = CONV #( lv_plant_str )
              storage_loc   = CONV #( lv_storage_loc_str )
              item_status   = 'D'
            ) TO lt_items.
          CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
            APPEND VALUE #(
              %tky = ls_key_upload-%tky
              %msg = new_message_with_text(
                severity = if_abap_behv_message=>severity-error
                text     = |Invalid number/date format in Excel row { lv_row }| )
            ) TO reported-header.
            EXIT.
        ENDTRY.

        lv_item_no = lv_item_no + 10.
        lv_row     = lv_row + 1.
      ENDDO.

      IF lt_items IS NOT INITIAL.
        INSERT zpur_upload_i FROM TABLE @lt_items.
      ENDIF.

    ENDLOOP.

    result = VALUE #( FOR ls_key IN keys
                      ( %tky = ls_key-%tky ) ).

  ENDMETHOD.

METHOD createPO.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers_po).

  LOOP AT lt_headers_po INTO DATA(ls_header_po).

    "Only Approved documents
    IF ls_header_po-Status <> 'A'.

      APPEND VALUE #(
        %tky = ls_header_po-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = 'Only Approved documents can create PO.' )
      ) TO reported-header.

      RETURN.

    ENDIF.

    "Prevent duplicate PO creation
    IF ls_header_po-PoNumber IS NOT INITIAL.

      APPEND VALUE #(
        %tky = ls_header_po-%tky
        %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text     = |PO already created: { ls_header_po-PoNumber }| )
      ) TO reported-header.

      RETURN.

    ENDIF.

    "Change status to Processing
    MODIFY ENTITIES OF zi_pur_upload_h IN LOCAL MODE
      ENTITY Header
      UPDATE FIELDS ( Status )
      WITH VALUE #( (
        %tky   = ls_header_po-%tky
        Status = 'J'
      ) ).

    APPEND VALUE #(
      %tky = ls_header_po-%tky
      %msg = new_message_with_text(
        severity = if_abap_behv_message=>severity-success
        text     = 'PO creation request submitted successfully.' )
    ) TO reported-header.

  ENDLOOP.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    ALL FIELDS
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_result).

  result = VALUE #(
    FOR ls_result IN lt_result
    (
      %tky   = ls_result-%tky
      %param = ls_result
    )
  ).

ENDMETHOD.

  METHOD processUploadedFile.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    FIELDS ( UploadUuid FileContent FileName )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_headers).

  LOOP AT lt_headers INTO DATA(ls_header).

    IF ls_header-UploadUuid IS INITIAL OR ls_header-FileContent IS INITIAL.
      CONTINUE.
    ENDIF.

    DELETE FROM zpur_upload_i
      WHERE upload_uuid = @ls_header-UploadUuid.

    DATA(lo_document) = xco_cp_xlsx=>document->for_file_content( ls_header-FileContent ).
    DATA(lo_read)     = lo_document->read_access( ).
    DATA(lo_workbook) = lo_read->get_workbook( ).
    DATA(lo_sheet)    = lo_workbook->worksheet->at_position( 1 ).

    DATA lt_items TYPE TABLE OF zpur_upload_i.
    DATA lv_row TYPE i VALUE 2.
    DATA lv_item_no TYPE zpur_upload_i-item_no VALUE '00010'.

    DATA: lv_vendor_str        TYPE string,
          lv_material_str      TYPE string,
          lv_short_text_str    TYPE string,
          lv_quantity_str      TYPE string,
          lv_unit_str          TYPE string,
          lv_price_str         TYPE string,
          lv_currency_str      TYPE string,
          lv_delivery_date_str TYPE string,
          lv_plant_str         TYPE string,
          lv_storage_loc_str   TYPE string.

    DO.
      CLEAR: lv_vendor_str, lv_material_str, lv_short_text_str,
             lv_quantity_str, lv_unit_str, lv_price_str,
             lv_currency_str, lv_delivery_date_str,
             lv_plant_str, lv_storage_loc_str.

      TRY.
          lo_sheet->cursor(
            io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value(
          )->set_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_vendor_str ) ).
        CATCH cx_sy_ref_is_initial.
          EXIT.
      ENDTRY.

      IF lv_vendor_str IS INITIAL.
        EXIT.
      ENDIF.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'B' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_material_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'C' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_short_text_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'D' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_quantity_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_unit_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_price_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'G' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_currency_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'H' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_delivery_date_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'I' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_plant_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'J' )
                            io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row )
          )->get_cell( )->get_value( )->set_transformation(
            xco_cp_xlsx_read_access=>value_transformation->string_value
          )->write_to( REF #( lv_storage_loc_str ) ).
        CATCH cx_sy_ref_is_initial.
      ENDTRY.

      TRY.
          APPEND VALUE zpur_upload_i(
            client        = sy-mandt
            upload_uuid   = ls_header-UploadUuid
            item_no       = lv_item_no
            vendor        = CONV #( lv_vendor_str )
            material      = CONV #( lv_material_str )
            short_text    = CONV #( lv_short_text_str )
            quantity      = CONV #( lv_quantity_str )
            unit          = CONV #( lv_unit_str )
            price         = CONV #( lv_price_str )
            currency      = CONV #( lv_currency_str )
            delivery_date = lv_delivery_date_str
            plant         = CONV #( lv_plant_str )
            storage_loc   = CONV #( lv_storage_loc_str )
            item_status   = 'D'
          ) TO lt_items.
        CATCH cx_sy_conversion_no_number cx_sy_conversion_overflow.
          APPEND VALUE #(
            %tky = ls_header-%tky
            %msg = new_message_with_text(
              severity = if_abap_behv_message=>severity-error
              text     = |Invalid number/date format in Excel row { lv_row }| )
          ) TO reported-header.
          EXIT.
      ENDTRY.

      lv_item_no = lv_item_no + 10.
      lv_row     = lv_row + 1.
    ENDDO.

    IF lt_items IS NOT INITIAL.
      INSERT zpur_upload_i FROM TABLE @lt_items.
    ENDIF.

  ENDLOOP.

ENDMETHOD.




METHOD send_approval_email.

  DATA lt_mgr TYPE TABLE OF zpur_app_mgr.

  SELECT *
    FROM zpur_app_mgr
    INTO TABLE @lt_mgr
    WHERE active = 'X'.

  IF lt_mgr IS INITIAL.
    RETURN.
  ENDIF.

 DATA lv_subject TYPE so_obj_des.

lv_subject = |PO Upload { iv_upload_no } Waiting for Approval|.

  DATA(lv_body) =
    |Dear Manager,| &&
    cl_abap_char_utilities=>newline &&
    cl_abap_char_utilities=>newline &&
    |A new PO Upload is waiting for your approval.| &&
    cl_abap_char_utilities=>newline &&
    |Upload No: { iv_upload_no }| &&
    cl_abap_char_utilities=>newline &&
    |Submitted By: { sy-uname }| &&
    cl_abap_char_utilities=>newline &&
    |Please review and take action in RAP Preview.|.

  TRY.

      DATA(lo_send_request) =
        cl_bcs=>create_persistent( ).

      DATA(lo_document) =
        cl_document_bcs=>create_document(
          i_type    = 'RAW'
          i_text    = VALUE soli_tab(
                        ( line = lv_body ) )
          i_subject = lv_subject ).

      lo_send_request->set_document( lo_document ).

      LOOP AT lt_mgr INTO DATA(ls_mgr).

        DATA(lo_recipient) =
          cl_cam_address_bcs=>create_internet_address(
            ls_mgr-manager_mail ).

        lo_send_request->add_recipient(
          i_recipient = lo_recipient
          i_express   = abap_true ).

      ENDLOOP.

      lo_send_request->send(
        i_with_error_screen = abap_true ).



    CATCH cx_bcs INTO DATA(lx_bcs).

  ENDTRY.

ENDMETHOD.



METHOD get_instance_features.

  READ ENTITIES OF zi_pur_upload_h IN LOCAL MODE
    ENTITY Header
    FIELDS ( Status PoNumber )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_header).

  result = VALUE #(
    FOR ls_header IN lt_header
    ( %tky = ls_header-%tky

      %action-submitForApproval = COND #(
        WHEN ls_header-Status = 'D'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )

      %action-approve = COND #(
        WHEN ls_header-Status = 'S'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )

      %action-reject = COND #(
        WHEN ls_header-Status = 'S'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )

      %action-createPO = COND #(
        WHEN ls_header-Status = 'A'
         AND ls_header-PoNumber IS INITIAL
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
    )
  ).

ENDMETHOD.


ENDCLASS.
